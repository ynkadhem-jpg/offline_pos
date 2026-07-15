import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/reports_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory temporaryDirectory;
  late AppDatabase database;
  late ReportsDao reportsDao;
  late int customerId;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_reports_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );

    database = AppDatabase();
    reportsDao = ReportsDao(database);
    customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Test customer',
            address: 'Test address',
            phone: '0000000000',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  Future<int> addProduct(String name, {bool isDeleted = false}) {
    final now = DateTime(2026, 1, 1);
    return database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            price: 100,
            isDeleted: Value(isDeleted),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<int> addSale({
    required int productId,
    double originalPrice = 80,
    double interestAmount = 20,
    bool isDeleted = false,
  }) {
    final totalAmount = originalPrice + interestAmount;
    return database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            customerId: customerId,
            productId: productId,
            originalPrice: originalPrice,
            interestAmount: interestAmount,
            totalAmount: totalAmount,
            months: 1,
            monthlyWithInterest: totalAmount,
            monthlyWithoutInterest: originalPrice,
            startDate: DateTime(2026, 1, 1),
            isDeleted: Value(isDeleted),
            createdAt: DateTime(2026, 1, 1),
          ),
        );
  }

  Future<int> addInstallment({
    required int saleId,
    required double actualDue,
    double totalPaid = 0,
    bool isPaid = false,
  }) {
    return database
        .into(database.installments)
        .insert(
          InstallmentsCompanion.insert(
            saleId: saleId,
            monthNumber: 1,
            dueDate: DateTime(2026, 2, 1),
            baseAmount: actualDue,
            carriedBalance: 0,
            actualDue: actualDue,
            totalPaid: totalPaid,
            isPaid: Value(isPaid),
          ),
        );
  }

  test('empty database returns zero totals and no top products', () async {
    final summary = await reportsDao.watchSummary().first;
    final products = await reportsDao.watchTopSellingProducts().first;

    expect(summary.totalProfit, 0);
    expect(summary.totalCollected, 0);
    expect(summary.totalSales, 0);
    expect(summary.remainingBalance, 0);
    expect(products, isEmpty);
  });

  test('active unpaid sale contributes its count and full remaining', () async {
    final productId = await addProduct('Product');
    final saleId = await addSale(productId: productId);
    await addInstallment(saleId: saleId, actualDue: 100);

    final summary = await reportsDao.watchSummary().first;

    expect(summary.totalSales, 1);
    expect(summary.remainingBalance, closeTo(100, 1e-10));
    expect(summary.totalProfit, closeTo(0, 1e-10));
  });

  test(
    'partial payment reduces remaining and recognizes interest proportionally',
    () async {
      final productId = await addProduct('Product');
      final saleId = await addSale(productId: productId);
      await addInstallment(saleId: saleId, actualDue: 100, totalPaid: 40);

      final summary = await reportsDao.watchSummary().first;

      expect(summary.remainingBalance, closeTo(60, 1e-10));
      expect(summary.totalCollected, closeTo(40, 1e-10));
      expect(summary.totalProfit, closeTo(8, 1e-10));
    },
  );

  test('full payment recognizes full proportional interest', () async {
    final productId = await addProduct('Product');
    final saleId = await addSale(productId: productId);
    await addInstallment(
      saleId: saleId,
      actualDue: 100,
      totalPaid: 100,
      isPaid: true,
    );

    final summary = await reportsDao.watchSummary().first;

    expect(summary.remainingBalance, 0);
    expect(summary.totalCollected, closeTo(100, 1e-10));
    expect(summary.totalProfit, closeTo(20, 1e-10));
  });

  test('overpayment is capped for remaining balance and profit', () async {
    final productId = await addProduct('Product');
    final saleId = await addSale(productId: productId);
    await addInstallment(
      saleId: saleId,
      actualDue: 100,
      totalPaid: 140,
      isPaid: true,
    );

    final summary = await reportsDao.watchSummary().first;

    expect(summary.remainingBalance, 0);
    expect(summary.totalCollected, closeTo(140, 1e-10));
    expect(summary.totalProfit, closeTo(20, 1e-10));
  });

  test('zero-interest sale contributes no profit', () async {
    final productId = await addProduct('Product');
    final saleId = await addSale(
      productId: productId,
      originalPrice: 100,
      interestAmount: 0,
    );
    await addInstallment(
      saleId: saleId,
      actualDue: 100,
      totalPaid: 100,
      isPaid: true,
    );

    final summary = await reportsDao.watchSummary().first;

    expect(summary.totalProfit, 0);
  });

  test('soft-deleted sale is excluded from every metric and ranking', () async {
    final productId = await addProduct('Product');
    final saleId = await addSale(productId: productId, isDeleted: true);
    await addInstallment(saleId: saleId, actualDue: 100, totalPaid: 40);

    final summary = await reportsDao.watchSummary().first;
    final products = await reportsDao.watchTopSellingProducts().first;

    expect(summary.totalSales, 0);
    expect(summary.remainingBalance, 0);
    expect(summary.totalCollected, 0);
    expect(summary.totalProfit, 0);
    expect(products, isEmpty);
  });

  test('top products use active sale counts and return only five', () async {
    for (var index = 0; index < 6; index++) {
      final productId = await addProduct('Product $index');
      for (var sale = 0; sale <= index; sale++) {
        await addSale(productId: productId);
      }
    }

    final products = await reportsDao.watchTopSellingProducts().first;

    expect(products, hasLength(5));
    expect(products.map((product) => product.salesCount), [6, 5, 4, 3, 2]);
  });

  test('duplicate names stay separate and ties use product ID order', () async {
    final firstProductId = await addProduct('Same name');
    final secondProductId = await addProduct('Same name');
    await addSale(productId: firstProductId);
    await addSale(productId: secondProductId);

    final products = await reportsDao.watchTopSellingProducts().first;

    expect(products, hasLength(2));
    expect(products.map((product) => product.productId), [
      firstProductId,
      secondProductId,
    ]);
  });

  test('soft-deleted product remains eligible with active sales', () async {
    final productId = await addProduct('Deleted product', isDeleted: true);
    await addSale(productId: productId);
    await addSale(productId: productId, isDeleted: true);

    final products = await reportsDao.watchTopSellingProducts().first;

    expect(products, hasLength(1));
    expect(products.single.productId, productId);
    expect(products.single.salesCount, 1);
    expect(products.single.isDeleted, isTrue);
  });
}
