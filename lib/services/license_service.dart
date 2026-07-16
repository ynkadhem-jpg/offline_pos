import 'package:shared_preferences/shared_preferences.dart';

import 'clock_validation_service.dart';
import 'device_fingerprint_service.dart';
import 'license_model.dart';

class LicenseService {
  LicenseService({
    DeviceFingerprintService? deviceFingerprintService,
    this.clockValidationService,
    SharedPreferencesAsync? preferences,
    DateTime Function()? now,
  }) : _deviceFingerprintService =
           deviceFingerprintService ?? const DeviceFingerprintService(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _now = now ?? (() => DateTime.now().toUtc());

  static const int trialDurationDays = 7;

  static const _activatedKey = 'licensing.activated';
  static const _activationCodeKey = 'licensing.activationCode';
  static const _fingerprintKey = 'licensing.fingerprint';
  static const _licenseTypeKey = 'licensing.licenseType';
  static const _activatedAtKey = 'licensing.activatedAt';
  static const _expiresAtKey = 'licensing.expiresAt';

  final DeviceFingerprintService _deviceFingerprintService;
  final SharedPreferencesAsync _preferences;
  final ClockValidationService? clockValidationService;
  final DateTime Function() _now;

  bool _initialized = false;
  LicenseStatus _status = LicenseStatus.unactivated;
  String _deviceFingerprint = '';
  String? _activationCode;
  LicenseType? _licenseType;
  DateTime? _activatedAt;
  DateTime? _expiresAt;
  ClockValidationResult? _clockValidationResult;

  bool get isActivated {
    _ensureInitialized();
    return _status == LicenseStatus.active;
  }

  bool get isTrialExpired {
    _ensureInitialized();
    return _status == LicenseStatus.trialExpired;
  }

  bool get isClockTampered {
    _ensureInitialized();
    return _status == LicenseStatus.clockTampered;
  }

  LicenseStatus get status {
    _ensureInitialized();
    return _status;
  }

  String get deviceFingerprint {
    _ensureInitialized();
    return _deviceFingerprint;
  }

  String? get activationCode {
    _ensureInitialized();
    return _activationCode;
  }

  LicenseType? get licenseType {
    _ensureInitialized();
    return _licenseType;
  }

  DateTime? get activatedAt {
    _ensureInitialized();
    return _activatedAt;
  }

  DateTime? get expiresAt {
    _ensureInitialized();
    return _expiresAt;
  }

  DateTime? get currentDeviceTime {
    _ensureInitialized();
    return _clockValidationResult?.currentDeviceTime;
  }

  DateTime? get lastTrustedTime {
    _ensureInitialized();
    return _clockValidationResult?.lastTrustedTime;
  }

  DateTime? get lastRunTime {
    _ensureInitialized();
    return _clockValidationResult?.lastRunTime;
  }

  DateTime? get lastValidationTime {
    _ensureInitialized();
    return _clockValidationResult?.lastValidationTime;
  }

  int? get remainingTrialDays {
    _ensureInitialized();
    if (_licenseType != LicenseType.trial || _expiresAt == null) return null;

    final currentTime = _clockValidationResult?.currentDeviceTime ?? _now();
    final remaining = _expiresAt!.difference(currentTime);
    if (remaining <= Duration.zero) return 0;
    return (remaining.inSeconds / const Duration(days: 1).inSeconds).ceil();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final fingerprint = await _deviceFingerprintService.deviceFingerprint;
    _deviceFingerprint = fingerprint;

    final clockResult =
        await (clockValidationService ??
                ClockValidationService(preferences: _preferences, now: _now))
            .validateStartup();
    _clockValidationResult = clockResult;

    if (clockResult.isTampered) {
      _status = LicenseStatus.clockTampered;
      _initialized = true;
      return;
    }

    final storedActivated = await _preferences.getBool(_activatedKey) ?? false;
    final storedActivationCode = await _preferences.getString(
      _activationCodeKey,
    );
    final storedFingerprint = await _preferences.getString(_fingerprintKey);
    final storedLicenseType = await _preferences.getString(_licenseTypeKey);
    final storedActivatedAt = await _preferences.getString(_activatedAtKey);
    final storedExpiresAt = await _preferences.getString(_expiresAtKey);

    _activationCode = storedActivationCode;

    final isStoredActivationValid =
        storedActivated &&
        storedFingerprint == fingerprint &&
        storedActivationCode != null &&
        storedActivationCode.trim().isNotEmpty;

    if (!isStoredActivationValid) {
      _status = LicenseStatus.unactivated;
      _initialized = true;
      return;
    }

    _licenseType = LicenseType.parse(storedLicenseType) ?? LicenseType.lifetime;
    _activatedAt = _parseUtc(storedActivatedAt);
    _expiresAt = _parseUtc(storedExpiresAt);
    _status = _resolveStatus(
      _licenseType,
      activatedAt: _activatedAt,
      expiresAt: _expiresAt,
      clockResult: clockResult,
    );
    _initialized = true;
  }

  Future<void> storeActivation({
    required String activationCode,
    required LicenseType licenseType,
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) async {
    _ensureInitialized();

    final normalizedCode = activationCode.replaceAll(RegExp(r'\s+'), '').trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(
        activationCode,
        'activationCode',
        'Activation code must not be empty.',
      );
    }

    final currentTime = _now().toUtc();
    final activatedAt = licenseType == LicenseType.trial
        ? issuedAt?.toUtc()
        : currentTime;
    final effectiveExpiresAt = licenseType == LicenseType.trial
        ? expiresAt?.toUtc()
        : null;
    if (licenseType == LicenseType.trial &&
        (activatedAt == null ||
            effectiveExpiresAt == null ||
            !effectiveExpiresAt.isAfter(activatedAt))) {
      throw ArgumentError(
        'Trial activation requires a valid signed issue and expiration time.',
      );
    }

    await _preferences.setBool(_activatedKey, true);
    await _preferences.setString(_activationCodeKey, normalizedCode);
    await _preferences.setString(_fingerprintKey, _deviceFingerprint);
    await _preferences.setString(_licenseTypeKey, licenseType.storageValue);
    await _preferences.setString(_activatedAtKey, _formatUtc(activatedAt!));
    if (effectiveExpiresAt == null) {
      await _preferences.remove(_expiresAtKey);
    } else {
      await _preferences.setString(
        _expiresAtKey,
        _formatUtc(effectiveExpiresAt),
      );
    }

    _activationCode = normalizedCode;
    _licenseType = licenseType;
    _activatedAt = activatedAt;
    _expiresAt = effectiveExpiresAt;
    _status = _resolveStatus(
      licenseType,
      activatedAt: activatedAt,
      expiresAt: effectiveExpiresAt,
      clockResult: _clockValidationResult!,
      evaluationTime: currentTime,
    );
  }

  Future<void> clearActivation() async {
    _ensureInitialized();

    await _preferences.remove(_activatedKey);
    await _preferences.remove(_activationCodeKey);
    await _preferences.remove(_fingerprintKey);
    await _preferences.remove(_licenseTypeKey);
    await _preferences.remove(_activatedAtKey);
    await _preferences.remove(_expiresAtKey);

    _activationCode = null;
    _licenseType = null;
    _activatedAt = null;
    _expiresAt = null;
    _status = LicenseStatus.unactivated;
  }

  LicenseStatus _resolveStatus(
    LicenseType? type, {
    required DateTime? activatedAt,
    required DateTime? expiresAt,
    required ClockValidationResult clockResult,
    DateTime? evaluationTime,
  }) {
    if (type == LicenseType.trial) {
      final currentDeviceTime =
          evaluationTime?.toUtc() ?? clockResult.currentDeviceTime;
      final isBeforeActivation = ClockValidationService.isBeforeActivationTime(
        currentDeviceTime,
        activatedAt,
      );
      final isBeforeTrusted = ClockValidationService.isBeforeTrustedTime(
        currentDeviceTime,
        clockResult.lastTrustedTime,
      );
      final isExpired = ClockValidationService.isAfterExpirationTime(
        currentDeviceTime,
        expiresAt,
      );

      if (isBeforeActivation || isBeforeTrusted || isExpired) {
        return LicenseStatus.trialExpired;
      }
    }
    return LicenseStatus.active;
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

  void _ensureInitialized() {
    if (_initialized) return;
    throw StateError('LicenseService.initialize() must be called first.');
  }
}
