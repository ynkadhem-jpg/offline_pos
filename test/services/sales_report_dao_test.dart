import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/sales_report_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory temporaryDirectory;
  late AppDatabase database;
  late SalesReportDao dao;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_sales_report_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );
    database = AppDatabase();
    dao = SalesReportDao(database);
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  test('joins active sales and preserves referenced deleted names', () async {
    final now = DateTime(2026, 7, 1);
    final customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Deleted customer',
            address: 'Address',
            phone: '000',
            isDeleted: const Value(true),
            createdAt: now,
          ),
        );
    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            name: 'Deleted product',
            price: 100,
            isDeleted: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<int> insertSale({
      required DateTime startDate,
      bool isDeleted = false,
    }) {
      return database
          .into(database.sales)
          .insert(
            SalesCompanion.insert(
              customerId: customerId,
              productId: productId,
              originalPrice: 80,
              interestAmount: 20,
              totalAmount: 100,
              months: 1,
              monthlyWithInterest: 100,
              monthlyWithoutInterest: 80,
              startDate: startDate,
              isDeleted: Value(isDeleted),
              createdAt: now,
            ),
          );
    }

    await insertSale(startDate: DateTime(2026, 6, 1));
    final paidSaleId = await insertSale(startDate: DateTime(2026, 7, 1));
    await insertSale(startDate: DateTime(2026, 8, 1), isDeleted: true);
    await database
        .into(database.installments)
        .insert(
          InstallmentsCompanion.insert(
            saleId: paidSaleId,
            monthNumber: 1,
            dueDate: DateTime(2026, 8, 1),
            baseAmount: 100,
            carriedBalance: 0,
            actualDue: 100,
            totalPaid: 100,
            isPaid: const Value(true),
          ),
        );

    final rows = await dao.watchActiveSales().first;

    expect(rows, hasLength(2));
    expect(rows.map((row) => row.startDate.month), [7, 6]);
    expect(rows.every((row) => row.customerName == 'Deleted customer'), isTrue);
    expect(rows.every((row) => row.productName == 'Deleted product'), isTrue);
    expect(rows.first.isFullyPaid, isTrue);
    expect(rows.last.isFullyPaid, isFalse);
  });
}
