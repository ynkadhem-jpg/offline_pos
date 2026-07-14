import 'package:flutter/services.dart';

class StoredAutomaticBackup {
  const StoredAutomaticBackup({
    required this.identifier,
    required this.name,
    required this.modifiedAtUtc,
    required this.size,
  });

  final String identifier;
  final String name;
  final DateTime modifiedAtUtc;
  final int size;
}

abstract interface class AutomaticBackupStorage {
  Future<StoredAutomaticBackup> storeFile({
    required String sourcePath,
    required String fileName,
  });

  Future<List<StoredAutomaticBackup>> listAutomaticBackups();

  Future<void> deleteBackup(StoredAutomaticBackup backup);
}

class AndroidAutomaticBackupStorage implements AutomaticBackupStorage {
  const AndroidAutomaticBackupStorage();

  static const _channel = MethodChannel(
    'offline_pos/automatic_backup_storage',
  );

  @override
  Future<StoredAutomaticBackup> storeFile({
    required String sourcePath,
    required String fileName,
  }) async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'storeFile',
      {'sourcePath': sourcePath, 'fileName': fileName},
    );
    if (value == null) {
      throw PlatformException(
        code: 'store_failed',
        message: 'Android did not return the stored backup.',
      );
    }
    return _fromMap(value);
  }

  @override
  Future<List<StoredAutomaticBackup>> listAutomaticBackups() async {
    final values = await _channel.invokeListMethod<Object?>(
      'listAutomaticBackups',
    );
    return (values ?? const <Object?>[])
        .map((value) => _fromMap(Map<Object?, Object?>.from(value! as Map)))
        .toList(growable: false);
  }

  @override
  Future<void> deleteBackup(StoredAutomaticBackup backup) {
    return _channel.invokeMethod<void>(
      'deleteBackup',
      {'identifier': backup.identifier, 'fileName': backup.name},
    );
  }

  StoredAutomaticBackup _fromMap(Map<Object?, Object?> value) {
    return StoredAutomaticBackup(
      identifier: value['identifier']! as String,
      name: value['name']! as String,
      modifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        value['modifiedAtMillis']! as int,
        isUtc: true,
      ),
      size: value['size']! as int,
    );
  }
}
