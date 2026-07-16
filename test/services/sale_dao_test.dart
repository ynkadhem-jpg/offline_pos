import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/sale_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory temporaryDirectory;
  late AppDatabase database;
  late SaleDao saleDao;
  late int customerId;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_sale_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );

    database = AppDatabase();
    saleDao = SaleDao(database);

    final now = DateTime(2026);
    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            name: 'iPhone 15',
            price: 1200000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Ahmed Ali',
            address: 'Baghdad',
            phone: '07700000000',
            createdAt: now,
          ),
        );

    await saleDao.createSale(
      customerId: customerId,
      productId: productId,
      originalPrice: 1200000,
      interestAmount: 200000,
      months: 10,
      startDate: DateTime(2026, 7, 14),
    );
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  test('getCustomerSales returns the current customer sale snapshot', () async {
    final sales = await saleDao.getCustomerSales(customerId);

    expect(sales, hasLength(1));
    expect(sales.single.product.name, 'iPhone 15');
    expect(sales.single.sale.months, 10);
    expect(sales.single.installments, hasLength(10));
  });
}
