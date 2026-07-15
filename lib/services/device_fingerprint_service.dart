import 'package:flutter/services.dart';

class DeviceFingerprintException implements Exception {
  const DeviceFingerprintException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return message;
    return '$message: $cause';
  }
}

class DeviceFingerprintService {
  const DeviceFingerprintService();

  static const MethodChannel _channel = MethodChannel(
    'com.example.offline_pos/device_fingerprint',
  );

  Future<String> get deviceFingerprint async {
    try {
      final fingerprint = await _channel.invokeMethod<String>('getFingerprint');
      final normalized = fingerprint?.trim();

      if (normalized == null || normalized.isEmpty) {
        throw const DeviceFingerprintException('تعذر إنشاء بصمة الجهاز.');
      }

      return normalized;
    } on PlatformException catch (error) {
      throw DeviceFingerprintException('تعذر قراءة بصمة الجهاز.', error);
    }
  }
}
