import 'package:shared_preferences/shared_preferences.dart';

import 'device_fingerprint_service.dart';

class LicenseService {
  LicenseService({
    DeviceFingerprintService? deviceFingerprintService,
    SharedPreferencesAsync? preferences,
  }) : _deviceFingerprintService =
           deviceFingerprintService ?? const DeviceFingerprintService(),
       _preferences = preferences ?? SharedPreferencesAsync();

  static const _activatedKey = 'licensing.activated';
  static const _activationCodeKey = 'licensing.activationCode';
  static const _fingerprintKey = 'licensing.fingerprint';

  final DeviceFingerprintService _deviceFingerprintService;
  final SharedPreferencesAsync _preferences;

  bool _initialized = false;
  bool _isActivated = false;
  String _deviceFingerprint = '';
  String? _activationCode;

  bool get isActivated {
    _ensureInitialized();
    return _isActivated;
  }

  String get deviceFingerprint {
    _ensureInitialized();
    return _deviceFingerprint;
  }

  String? get activationCode {
    _ensureInitialized();
    return _activationCode;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final fingerprint = await _deviceFingerprintService.deviceFingerprint;
    final storedActivated = await _preferences.getBool(_activatedKey) ?? false;
    final storedActivationCode = await _preferences.getString(
      _activationCodeKey,
    );
    final storedFingerprint = await _preferences.getString(_fingerprintKey);

    _deviceFingerprint = fingerprint;
    _activationCode = storedActivationCode;
    _isActivated =
        storedActivated &&
        storedFingerprint == fingerprint &&
        storedActivationCode != null &&
        storedActivationCode.trim().isNotEmpty;
    _initialized = true;
  }

  Future<void> storeActivation({required String activationCode}) async {
    _ensureInitialized();

    final normalizedCode = activationCode.replaceAll(RegExp(r'\s+'), '').trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(
        activationCode,
        'activationCode',
        'Activation code must not be empty.',
      );
    }

    await _preferences.setBool(_activatedKey, true);
    await _preferences.setString(_activationCodeKey, normalizedCode);
    await _preferences.setString(_fingerprintKey, _deviceFingerprint);

    _activationCode = normalizedCode;
    _isActivated = true;
  }

  Future<void> clearActivation() async {
    _ensureInitialized();

    await _preferences.remove(_activatedKey);
    await _preferences.remove(_activationCodeKey);
    await _preferences.remove(_fingerprintKey);

    _activationCode = null;
    _isActivated = false;
  }

  void _ensureInitialized() {
    if (_initialized) return;
    throw StateError('LicenseService.initialize() must be called first.');
  }
}
