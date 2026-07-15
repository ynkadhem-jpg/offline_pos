import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/database.dart';
import 'package:taqseet/services/payment_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory temporaryDirectory;
  late AppDatabase database;
  late PaymentDao paymentDao;
  late int firstInstallmentId;
  late int secondInstallmentId;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline_pos_payment_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => temporaryDirectory.path,
        );

    database = AppDatabase();
    paymentDao = PaymentDao(database);

    final now = DateTime(2026, 1, 1);
    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            name: 'Test product',
            price: 200,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final customerId = await database
        .into(database.customers)
        .insert(
          CustomersCompanion.insert(
            name: 'Test customer',
            address: 'Test address',
            phone: '0000000000',
            createdAt: now,
          ),
        );
    final saleId = await database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            customerId: customerId,
            productId: productId,
            originalPrice: 200,
            interestAmount: 0,
            totalAmount: 200,
            months: 2,
            monthlyWithInterest: 100,
            monthlyWithoutInterest: 100,
            startDate: now,
            createdAt: now,
          ),
        );
    firstInstallmentId = await database
        .into(database.installments)
        .insert(
          InstallmentsCompanion.insert(
            saleId: saleId,
            monthNumber: 1,
            dueDate: DateTime(2026, 2, 1),
            baseAmount: 100,
            carriedBalance: 0,
            actualDue: 100,
            totalPaid: 0,
          ),
        );
    secondInstallmentId = await database
        .into(database.installments)
        .insert(
          InstallmentsCompanion.insert(
            saleId: saleId,
            monthNumber: 2,
            dueDate: DateTime(2026, 3, 1),
            baseAmount: 100,
            carriedBalance: 0,
            actualDue: 100,
            totalPaid: 0,
          ),
        );
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  Future<Installment> loadInstallment(int id) {
    return (database.select(
      database.installments,
    )..where((installment) => installment.id.equals(id))).getSingle();
  }

  Future<List<Payment>> loadPayments() {
    return database.select(database.payments).get();
  }

  test('partial payment increases totalPaid and remains unpaid', () async {
    await paymentDao.recordPayment(
      installmentId: firstInstallmentId,
      amount: 40,
      paymentDate: DateTime(2026, 1, 10),
    );

    final installment = await loadInstallment(firstInstallmentId);
    final payments = await loadPayments();

    expect(installment.totalPaid, 40);
    expect(installment.isPaid, isFalse);
    expect(installment.actualDue - installment.totalPaid, 60);
    expect(payments.single.installmentId, firstInstallmentId);
  });

  test(
    'exact payment marks the installment paid with zero remaining',
    () async {
      await paymentDao.recordPayment(
        installmentId: firstInstallmentId,
        amount: 100,
        paymentDate: DateTime(2026, 1, 10),
      );

      final installment = await loadInstallment(firstInstallmentId);

      expect(installment.totalPaid, 100);
      expect(installment.isPaid, isTrue);
      expect(installment.actualDue - installment.totalPaid, 0);
    },
  );

  test(
    'overpayment stays on its installment and displays zero remaining',
    () async {
      await paymentDao.recordPayment(
        installmentId: firstInstallmentId,
        amount: 120,
        paymentDate: DateTime(2026, 1, 10),
      );

      final firstInstallment = await loadInstallment(firstInstallmentId);
      final secondInstallment = await loadInstallment(secondInstallmentId);
      final calculatedRemaining =
          firstInstallment.actualDue - firstInstallment.totalPaid;
      final displayedRemaining = calculatedRemaining > 0
          ? calculatedRemaining
          : 0.0;

      expect(firstInstallment.totalPaid, 120);
      expect(firstInstallment.isPaid, isTrue);
      expect(displayedRemaining, 0);
      expect(secondInstallment.totalPaid, 0);
      expect(secondInstallment.isPaid, isFalse);
    },
  );

  test('multiple payments accumulate on the same installment', () async {
    await paymentDao.recordPayment(
      installmentId: firstInstallmentId,
      amount: 30,
      paymentDate: DateTime(2026, 1, 10),
    );
    await paymentDao.recordPayment(
      installmentId: firstInstallmentId,
      amount: 20,
      paymentDate: DateTime(2026, 1, 11),
    );

    final installment = await loadInstallment(firstInstallmentId);
    final payments = await loadPayments();

    expect(installment.totalPaid, 50);
    expect(installment.isPaid, isFalse);
    expect(payments.map((payment) => payment.amount), containsAll([30, 20]));
    expect(
      payments.every((payment) => payment.installmentId == firstInstallmentId),
      isTrue,
    );
  });

  test('already paid installment rejects payment without changes', () async {
    await (database.update(
      database.installments,
    )..where((installment) => installment.id.equals(firstInstallmentId))).write(
      const InstallmentsCompanion(totalPaid: Value(100), isPaid: Value(true)),
    );

    await expectLater(
      paymentDao.recordPayment(
        installmentId: firstInstallmentId,
        amount: 10,
        paymentDate: DateTime(2026, 1, 10),
      ),
      throwsA(isA<StateError>()),
    );

    final installment = await loadInstallment(firstInstallmentId);
    expect(installment.totalPaid, 100);
    expect(installment.isPaid, isTrue);
    expect(await loadPayments(), isEmpty);
  });

  test('invalid installment ID creates no payment', () async {
    await expectLater(
      paymentDao.recordPayment(
        installmentId: 999999,
        amount: 10,
        paymentDate: DateTime(2026, 1, 10),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await loadPayments(), isEmpty);
  });

  test('zero and negative payment amounts are rejected', () async {
    for (final amount in [0.0, -1.0]) {
      expect(
        () => paymentDao.recordPayment(
          installmentId: firstInstallmentId,
          amount: amount,
          paymentDate: DateTime(2026, 1, 10),
        ),
        throwsArgumentError,
      );
    }

    expect(await loadPayments(), isEmpty);
  });
}
