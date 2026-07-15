import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/automatic_backup_service.dart';
import 'package:taqseet/services/automatic_backup_storage.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;
  late AppDatabase database;
  late DateTime now;
  late FakeAutomaticBackupStorage storage;
  late FakeTimestampStore timestampStore;
  late AutomaticBackupService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_auto_backup_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );
    database = AppDatabase();
    now = DateTime.utc(2026, 7, 14, 12, 30);
    storage = FakeAutomaticBackupStorage(() => now);
    timestampStore = FakeTimestampStore();
    service = AutomaticBackupService(
      localBackupService: LocalBackupService(),
      storage: storage,
      timestampStore: timestampStore,
      clock: () => now,
    );
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('creates a strict automatic-backup name and saves UTC time', () async {
    final result = await service.runIfDue(database);

    expect(result.status, AutomaticBackupStatus.created);
    expect(storage.backups.single.name,
        'offline_pos_auto_backup_2026-07-14_123000.db');
    expect(timestampStore.value, now);
    expect(storage.lastCopiedSize, greaterThan(0));
  });

  test('does not create another backup inside a rolling 24 hours', () async {
    expect(
      (await service.runIfDue(database)).status,
      AutomaticBackupStatus.created,
    );
    now = now.add(const Duration(hours: 23, minutes: 59));

    final result = await service.runIfDue(database);

    expect(result.status, AutomaticBackupStatus.notDue);
    expect(storage.backups, hasLength(1));
  });

  test('creates a backup when exactly 24 hours have elapsed', () async {
    await service.runIfDue(database);
    now = now.add(const Duration(hours: 24));

    final result = await service.runIfDue(database);

    expect(result.status, AutomaticBackupStatus.created);
    expect(storage.backups, hasLength(2));
  });

  test('newest stored file prevents duplication if timestamp write fails',
      () async {
    timestampStore.failWrites = true;
    final first = await service.runIfDue(database);
    expect(first.status, AutomaticBackupStatus.created);
    expect(first.failure, isNotNull);

    timestampStore.failWrites = false;
    now = now.add(const Duration(hours: 1));
    final second = await service.runIfDue(database);

    expect(second.status, AutomaticBackupStatus.notDue);
    expect(storage.backups, hasLength(1));
  });

  test('retention keeps seven strict matches and ignores unrelated files',
      () async {
    for (var day = 1; day <= 9; day++) {
      storage.backups.add(
        StoredAutomaticBackup(
          identifier: 'owned-$day',
          name: 'offline_pos_auto_backup_2026-07-${day.toString().padLeft(2, '0')}_120000.db',
          modifiedAtUtc: DateTime.utc(2026, 7, day, 12),
          size: day,
        ),
      );
    }
    storage.backups.add(
      StoredAutomaticBackup(
        identifier: 'unrelated',
        name: 'some_other_backup.db',
        modifiedAtUtc: now,
        size: 1,
      ),
    );
    timestampStore.value = now;

    final result = await service.runIfDue(database);

    expect(result.status, AutomaticBackupStatus.notDue);
    expect(storage.deletedIdentifiers, ['owned-2', 'owned-1']);
    expect(storage.backups.any((backup) => backup.identifier == 'unrelated'),
        isTrue);
  });

  test('in-memory guard prevents two concurrent runs', () async {
    storage.storeGate = Completer<void>();
    final firstRun = service.runIfDue(database);
    await storage.storeStarted.future;

    final second = await service.runIfDue(database);
    expect(second.status, AutomaticBackupStatus.alreadyRunning);

    storage.storeGate!.complete();
    expect((await firstRun).status, AutomaticBackupStatus.created);
  });
}

class FakeTimestampStore implements AutomaticBackupTimestampStore {
  DateTime? value;
  bool failWrites = false;

  @override
  Future<DateTime?> readLastSuccessfulBackupUtc() async => value;

  @override
  Future<void> writeLastSuccessfulBackupUtc(DateTime value) async {
    if (failWrites) throw StateError('timestamp write failed');
    this.value = value.toUtc();
  }
}

class FakeAutomaticBackupStorage implements AutomaticBackupStorage {
  FakeAutomaticBackupStorage(this.clock);

  final DateTime Function() clock;
  final List<StoredAutomaticBackup> backups = [];
  final List<String> deletedIdentifiers = [];
  final Completer<void> storeStarted = Completer<void>();
  Completer<void>? storeGate;
  int? lastCopiedSize;

  @override
  Future<StoredAutomaticBackup> storeFile({
    required String sourcePath,
    required String fileName,
  }) async {
    if (!storeStarted.isCompleted) storeStarted.complete();
    await storeGate?.future;
    lastCopiedSize = await File(sourcePath).length();
    final backup = StoredAutomaticBackup(
      identifier: 'stored-${backups.length}',
      name: fileName,
      modifiedAtUtc: clock().toUtc(),
      size: lastCopiedSize!,
    );
    backups.add(backup);
    return backup;
  }

  @override
  Future<List<StoredAutomaticBackup>> listAutomaticBackups() async =>
      List.of(backups);

  @override
  Future<String> copyBackupToCache(StoredAutomaticBackup backup) async {
    return backup.identifier;
  }

  @override
  Future<void> deleteBackup(StoredAutomaticBackup backup) async {
    deletedIdentifiers.add(backup.identifier);
    backups.removeWhere((value) => value.identifier == backup.identifier);
  }
}
