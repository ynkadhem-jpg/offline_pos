import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  late Directory temporaryDirectory;
  late AppDatabase database;
  late LocalBackupService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_backup_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );
    database = AppDatabase();
    service = LocalBackupService(
      clock: () => DateTime(2026, 7, 14, 15, 30),
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

  Future<void> addProduct(String name) async {
    final now = DateTime(2026, 7, 14);
    await database.into(database.products).insert(
      ProductsCompanion.insert(
        name: name,
        price: 100,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('creates the required timestamped file name', () {
    expect(
      service.createBackupFileName(),
      'offline_pos_backup_2026-07-14_153000.db',
    );
  });

  test('exports a valid snapshot while the database is open', () async {
    await addProduct('Exported product');

    final result = await service.createExportSnapshot(database);

    expect(result.isSuccess, isTrue);
    final artifact = result.artifact!;
    expect(await artifact.file.exists(), isTrue);
    expect(artifact.size, greaterThan(0));
    expect((await service.validateBackup(artifact.file.path)).isValid, isTrue);
    await artifact.dispose();
  });

  test('rejects a non-SQLite file', () async {
    final invalid = File('${temporaryDirectory.path}/invalid.db');
    await invalid.writeAsString('not a sqlite database');

    final result = await service.validateBackup(invalid.path);

    expect(result.isValid, isFalse);
    expect(result.failure?.code, BackupFailureCode.invalidSqlite);
  });

  test('invalid restore leaves the current database unchanged', () async {
    await addProduct('Current product');
    final invalid = File('${temporaryDirectory.path}/invalid_restore.db');
    await invalid.writeAsString('not a sqlite database');

    final restore = await service.restoreBackup(
      currentDatabase: database,
      sourcePath: invalid.path,
    );

    expect(restore.isSuccess, isFalse);
    expect(identical(restore.activeDatabase, database), isTrue);
    final products = await database.select(database.products).get();
    expect(products.single.name, 'Current product');
  });

  test('restores an exported file by replacing the live database', () async {
    await addProduct('From backup');
    final export = await service.createExportSnapshot(database);
    final artifact = export.artifact!;
    await addProduct('Added later');

    final restore = await service.restoreBackup(
      currentDatabase: database,
      sourcePath: artifact.file.path,
    );
    database = restore.activeDatabase;

    expect(restore.isSuccess, isTrue);
    final products = await database.select(database.products).get();
    expect(products.map((product) => product.name), ['From backup']);
    await artifact.dispose();
  });
}
