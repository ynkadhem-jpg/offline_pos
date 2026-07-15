import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  test('bundled SQLite supports VACUUM INTO', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_sqlite_capabilities_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );

    final database = AppDatabase();
    final snapshot = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}snapshot.db',
    );

    try {
      final versionRow = await database
          .customSelect('SELECT sqlite_version() AS version')
          .getSingle();
      final version = versionRow.read<String>('version');

      final escapedPath = snapshot.path.replaceAll("'", "''");
      await database.customStatement("VACUUM INTO '$escapedPath'");

      expect(version, isNotEmpty, reason: 'Bundled SQLite version: $version');
      expect(await snapshot.exists(), isTrue);
      expect(await snapshot.length(), greaterThan(0));
    } finally {
      await database.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
