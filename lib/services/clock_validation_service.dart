import 'package:shared_preferences/shared_preferences.dart';

class ClockValidationResult {
  const ClockValidationResult({
    required this.isValid,
    required this.currentDeviceTime,
    required this.lastTrustedTime,
    required this.lastRunTime,
    required this.lastValidationTime,
  });

  final bool isValid;
  final DateTime currentDeviceTime;
  final DateTime? lastTrustedTime;
  final DateTime? lastRunTime;
  final DateTime? lastValidationTime;

  bool get isTampered => !isValid;
}

class ClockValidationService {
  ClockValidationService({
    SharedPreferencesAsync? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _now = now ?? (() => DateTime.now().toUtc());

  static const rollbackTolerance = Duration(minutes: 5);

  static const _lastTrustedTimeKey = 'licensing.clock.lastTrustedTime';
  static const _lastRunTimeKey = 'licensing.clock.lastRunTime';
  static const _lastValidationTimeKey = 'licensing.clock.lastValidationTime';

  final SharedPreferencesAsync _preferences;
  final DateTime Function() _now;

  Future<ClockValidationResult> validateStartup() async {
    final currentDeviceTime = _now().toUtc();
    final storedLastTrustedTime = _parseUtc(
      await _preferences.getString(_lastTrustedTimeKey),
    );
    final storedLastRunTime = _parseUtc(
      await _preferences.getString(_lastRunTimeKey),
    );
    final storedLastValidationTime = _parseUtc(
      await _preferences.getString(_lastValidationTimeKey),
    );

    if (_isRollback(currentDeviceTime, storedLastTrustedTime)) {
      return ClockValidationResult(
        isValid: false,
        currentDeviceTime: currentDeviceTime,
        lastTrustedTime: storedLastTrustedTime,
        lastRunTime: storedLastRunTime,
        lastValidationTime: storedLastValidationTime,
      );
    }

    final trustedTime = _latest(storedLastTrustedTime, currentDeviceTime);
    await _preferences.setString(_lastTrustedTimeKey, _formatUtc(trustedTime));
    await _preferences.setString(
      _lastRunTimeKey,
      _formatUtc(currentDeviceTime),
    );
    await _preferences.setString(
      _lastValidationTimeKey,
      _formatUtc(currentDeviceTime),
    );

    return ClockValidationResult(
      isValid: true,
      currentDeviceTime: currentDeviceTime,
      lastTrustedTime: trustedTime,
      lastRunTime: currentDeviceTime,
      lastValidationTime: currentDeviceTime,
    );
  }

  static bool isBeforeTrustedTime(
    DateTime currentDeviceTime,
    DateTime? lastTrustedTime,
  ) {
    return _isRollback(currentDeviceTime.toUtc(), lastTrustedTime);
  }

  static bool isBeforeActivationTime(
    DateTime currentDeviceTime,
    DateTime? activatedAt,
  ) {
    if (activatedAt == null) return true;
    return currentDeviceTime
        .toUtc()
        .add(rollbackTolerance)
        .isBefore(activatedAt.toUtc());
  }

  static bool isAfterExpirationTime(
    DateTime currentDeviceTime,
    DateTime? expiresAt,
  ) {
    if (expiresAt == null) return true;
    return currentDeviceTime.toUtc().isAfter(expiresAt.toUtc());
  }

  static bool _isRollback(DateTime currentDeviceTime, DateTime? trustedTime) {
    if (trustedTime == null) return false;
    return currentDeviceTime
        .add(rollbackTolerance)
        .isBefore(trustedTime.toUtc());
  }

  static DateTime _latest(DateTime? stored, DateTime current) {
    if (stored == null) return current;
    return current.isAfter(stored) ? current : stored;
  }

  static DateTime? _parseUtc(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static String _formatUtc(DateTime value) {
    return value.toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
  }
}
