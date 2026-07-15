import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/activation_validator.dart';

void main() {
  const activationCode =
      'TAQ1.eyJ2IjoxLCJhbGciOiJFZDI1NTE5Iiwia2lkIjoiZWQyNTUxOS1tYWluLXYxIiwiYXBwIjoidGFxc2VldCIsInR5cGUiOiJsaWZldGltZSIsInRpZXIiOiJzdGFuZGFyZCIsImZwIjoiQUJDRDEyMzQiLCJpYXQiOiIyMDI2LTA3LTE1VDIyOjIwOjQyWiJ9.S7mGXIpwmUdL9J37pS2UdiqoOBzz-137JZ-UJ0qHTFOhGRxszC0Zypq33C2-_C1Jz6CNdgIzBNuF0H9zRQV7Aw';

  test(
    'accepts a correctly signed activation code for the same fingerprint',
    () async {
      final result = await const ActivationValidator().validate(
        activationCode: activationCode.replaceAll('.', '.\n'),
        deviceFingerprint: 'AB CD-12:34',
      );

      expect(result.isValid, isTrue);
      expect(result.payload?.deviceFingerprint, 'ABCD1234');
      expect(result.payload?.type, 'lifetime');
    },
  );

  test(
    'rejects a correctly signed activation code for another fingerprint',
    () async {
      final result = await const ActivationValidator().validate(
        activationCode: activationCode,
        deviceFingerprint: 'FFFF1234',
      );

      expect(result.isValid, isFalse);
      expect(result.failure, ActivationValidationFailure.fingerprintMismatch);
    },
  );
}
