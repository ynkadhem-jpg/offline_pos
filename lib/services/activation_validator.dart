import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'license_public_key.dart';

enum ActivationValidationFailure {
  malformed,
  unsupportedVersion,
  unsupportedAlgorithm,
  wrongApplication,
  wrongKey,
  fingerprintMismatch,
  invalidSignature,
}

class ActivationValidationResult {
  const ActivationValidationResult.valid(this.payload) : failure = null;

  const ActivationValidationResult.invalid(this.failure) : payload = null;

  final LicensePayload? payload;
  final ActivationValidationFailure? failure;

  bool get isValid => payload != null;
}

class LicensePayload {
  const LicensePayload({
    required this.version,
    required this.algorithm,
    required this.keyId,
    required this.applicationId,
    required this.type,
    required this.tier,
    required this.deviceFingerprint,
    required this.issuedAt,
  });

  final int version;
  final String algorithm;
  final String keyId;
  final String applicationId;
  final String type;
  final String tier;
  final String deviceFingerprint;
  final DateTime issuedAt;
}

class ActivationValidator {
  const ActivationValidator();

  static const String codePrefix = 'TAQ1';
  static const String applicationId = 'taqseet';
  static const int supportedVersion = 1;

  Future<ActivationValidationResult> validate({
    required String activationCode,
    required String deviceFingerprint,
  }) async {
    final parsed = _ParsedActivationCode.parse(activationCode);
    if (parsed == null) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.malformed,
      );
    }

    final payload = _decodePayload(parsed.payloadBase64);
    if (payload == null) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.malformed,
      );
    }

    if (payload.version != supportedVersion) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.unsupportedVersion,
      );
    }
    if (payload.algorithm != LicensePublicKey.algorithm) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.unsupportedAlgorithm,
      );
    }
    if (payload.applicationId != applicationId) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.wrongApplication,
      );
    }
    if (payload.keyId != LicensePublicKey.keyId) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.wrongKey,
      );
    }
    if (payload.deviceFingerprint != _normalizeFingerprint(deviceFingerprint)) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.fingerprintMismatch,
      );
    }

    final isValid = await Ed25519().verify(
      utf8.encode('$codePrefix.${parsed.payloadBase64}'),
      signature: Signature(
        parsed.signatureBytes,
        publicKey: SimplePublicKey(
          LicensePublicKey.bytes,
          type: KeyPairType.ed25519,
        ),
      ),
    );

    if (!isValid) {
      return const ActivationValidationResult.invalid(
        ActivationValidationFailure.invalidSignature,
      );
    }

    return ActivationValidationResult.valid(payload);
  }

  static LicensePayload? _decodePayload(String payloadBase64) {
    try {
      final payloadBytes = base64Url.decode(base64Url.normalize(payloadBase64));
      final payloadJson = jsonDecode(utf8.decode(payloadBytes));
      if (payloadJson is! Map<String, Object?>) return null;

      final version = payloadJson['v'];
      final algorithm = payloadJson['alg'];
      final keyId = payloadJson['kid'];
      final applicationId = payloadJson['app'];
      final type = payloadJson['type'];
      final tier = payloadJson['tier'];
      final fingerprint = payloadJson['fp'];
      final issuedAt = payloadJson['iat'];

      if (version is! int ||
          algorithm is! String ||
          keyId is! String ||
          applicationId is! String ||
          type is! String ||
          tier is! String ||
          fingerprint is! String ||
          issuedAt is! String) {
        return null;
      }

      final parsedIssuedAt = DateTime.tryParse(issuedAt);
      if (parsedIssuedAt == null) return null;

      return LicensePayload(
        version: version,
        algorithm: algorithm,
        keyId: keyId,
        applicationId: applicationId,
        type: type,
        tier: tier,
        deviceFingerprint: _normalizeFingerprint(fingerprint),
        issuedAt: parsedIssuedAt.toUtc(),
      );
    } on FormatException {
      return null;
    }
  }

  static String _normalizeFingerprint(String value) {
    return value.replaceAll(RegExp(r'[\s:-]'), '').toUpperCase();
  }
}

class _ParsedActivationCode {
  const _ParsedActivationCode({
    required this.payloadBase64,
    required this.signatureBytes,
  });

  final String payloadBase64;
  final List<int> signatureBytes;

  static _ParsedActivationCode? parse(String activationCode) {
    final normalized = activationCode.replaceAll(RegExp(r'\s+'), '').trim();
    final parts = normalized.split('.');

    if (parts.length != 3 || parts.first != ActivationValidator.codePrefix) {
      return null;
    }

    try {
      return _ParsedActivationCode(
        payloadBase64: parts[1],
        signatureBytes: base64Url.decode(base64Url.normalize(parts[2])),
      );
    } on FormatException {
      return null;
    }
  }
}
