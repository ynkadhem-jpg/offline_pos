import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/customer_dao.dart';
import 'package:taqseet/services/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;
  late AppDatabase database;
  late CustomerDao customerDao;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_customer_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );
    database = AppDatabase();
    customerDao = CustomerDao(database);
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  test('updates customer data and soft delete hides the customer', () async {
    final id = await customerDao.addCustomer(
      name: 'Ahmed Ali',
      address: 'Baghdad',
      phone: '07700000000',
    );

    expect(
      await customerDao.updateCustomer(
        id: id,
        name: 'Ahmed Hassan',
        address: 'Al-Resafa',
        phone: '07711111111',
      ),
      1,
    );

    final updated = await (database.select(
      database.customers,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(updated.name, 'Ahmed Hassan');
    expect(updated.address, 'Al-Resafa');
    expect(updated.phone, '07711111111');

    expect(await customerDao.softDeleteCustomer(id), 1);
    expect(await customerDao.watchCustomers().first, isEmpty);

    final retained = await (database.select(
      database.customers,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(retained.isDeleted, isTrue);
  });
}
