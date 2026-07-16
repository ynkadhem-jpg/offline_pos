import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taqseet/services/device_fingerprint_service.dart';
import 'package:taqseet/services/license_model.dart';
import 'package:taqseet/services/license_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'stores a trial license that expires exactly after seven days',
    () async {
      final now = DateTime.utc(2026, 1, 1, 10);
      final service = LicenseService(
        deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
        now: () => now,
      );

      await service.initialize();
      await service.storeActivation(
        activationCode: 'TRIAL_CODE',
        licenseType: LicenseType.trial,
      );

      expect(service.isActivated, isTrue);
      expect(service.licenseType, LicenseType.trial);
      expect(service.activatedAt, now);
      expect(service.expiresAt, now.add(const Duration(days: 7)));
      expect(service.remainingTrialDays, 7);
    },
  );

  test('marks a trial license as expired after the expiration date', () async {
    final activatedAt = DateTime.utc(2026, 1, 1, 10);

    final service = LicenseService(
      deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
      now: () => activatedAt,
    );
    await service.initialize();
    await service.storeActivation(
      activationCode: 'TRIAL_CODE',
      licenseType: LicenseType.trial,
    );

    final expiredService = LicenseService(
      deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
      now: () => activatedAt.add(const Duration(days: 8)),
    );
    await expiredService.initialize();

    expect(expiredService.isActivated, isFalse);
    expect(expiredService.isTrialExpired, isTrue);
    expect(expiredService.remainingTrialDays, 0);
  });

  test(
    'treats existing activation records without a type as lifetime',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'licensing.activated': true,
            'licensing.activationCode': 'OLD_CODE',
            'licensing.fingerprint': 'FP',
          });

      final service = LicenseService(
        deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
      );
      await service.initialize();

      expect(service.isActivated, isTrue);
      expect(service.licenseType, LicenseType.lifetime);
      expect(service.expiresAt, isNull);
    },
  );

  test(
    'blocks startup when device time is rolled back beyond tolerance',
    () async {
      final previousTrustedTime = DateTime.utc(2026, 1, 10, 12);
      final rolledBackTime = previousTrustedTime.subtract(
        const Duration(minutes: 6),
      );
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'licensing.clock.lastTrustedTime': previousTrustedTime
                .toIso8601String(),
          });

      final service = LicenseService(
        deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
        now: () => rolledBackTime,
      );
      await service.initialize();

      expect(service.isActivated, isFalse);
      expect(service.isClockTampered, isTrue);
      expect(service.currentDeviceTime, rolledBackTime);
      expect(service.lastTrustedTime, previousTrustedTime);
    },
  );

  test('allows tiny clock adjustments within five minutes', () async {
    final previousTrustedTime = DateTime.utc(2026, 1, 10, 12);
    SharedPreferencesAsyncPlatform
        .instance = InMemorySharedPreferencesAsync.withData({
      'licensing.clock.lastTrustedTime': previousTrustedTime.toIso8601String(),
      'licensing.activated': true,
      'licensing.activationCode': 'LIFETIME_CODE',
      'licensing.fingerprint': 'FP',
      'licensing.licenseType': 'lifetime',
    });

    final service = LicenseService(
      deviceFingerprintService: const _FakeDeviceFingerprintService('FP'),
      now: () => previousTrustedTime.subtract(const Duration(minutes: 5)),
    );
    await service.initialize();

    expect(service.isClockTampered, isFalse);
    expect(service.isActivated, isTrue);
    expect(service.lastTrustedTime, previousTrustedTime);
  });
}

class _FakeDeviceFingerprintService extends DeviceFingerprintService {
  const _FakeDeviceFingerprintService(this.value);

  final String value;

  @override
  Future<String> get deviceFingerprint async => value;
}
