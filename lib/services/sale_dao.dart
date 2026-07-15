import 'package:drift/drift.dart';

import 'database.dart';
import 'installment_calculator.dart';

class CustomerSaleDetails {
  const CustomerSaleDetails({
    required this.sale,
    required this.product,
    required this.installments,
  });

  final Sale sale;
  final Product product;
  final List<Installment> installments;

  double get remainingAmount =>
      installments.fold<double>(0, (total, installment) {
        final remaining = installment.actualDue - installment.totalPaid;
        return total + (remaining > 0 ? remaining : 0);
      });
}

class SaleDao extends DatabaseAccessor<AppDatabase> {
  SaleDao(super.db);

  Future<int> createSale({
    required int customerId,
    required int productId,
    required double originalPrice,
    required double interestAmount,
    required int months,
    required DateTime startDate,
  }) async {
    _validateId(customerId, 'customerId');
    _validateId(productId, 'productId');

    final calculation = calculateInstallment(
      originalPrice: originalPrice,
      interestAmount: interestAmount,
      months: months,
    );

    return transaction(() async {
      await _ensureActiveCustomerExists(customerId);
      await _ensureActiveProductExists(productId);

      final saleId = await into(attachedDatabase.sales).insert(
        SalesCompanion.insert(
          customerId: customerId,
          productId: productId,
          originalPrice: originalPrice,
          interestAmount: interestAmount,
          totalAmount: calculation.totalAmount,
          months: months,
          monthlyWithInterest: calculation.monthlyWithInterest,
          monthlyWithoutInterest: calculation.monthlyWithoutInterest,
          startDate: startDate,
          isDeleted: const Value(false),
          createdAt: DateTime.now(),
        ),
      );

      final installments = [
        for (var monthNumber = 1; monthNumber <= months; monthNumber++)
          _newInstallment(
            saleId: saleId,
            monthNumber: monthNumber,
            startDate: startDate,
            monthlyAmount: calculation.monthlyWithInterest,
          ),
      ];

      await attachedDatabase.batch((batch) {
        batch.insertAll(attachedDatabase.installments, installments);
      });

      return saleId;
    });
  }

  Future<void> updateSale({
    required int saleId,
    required double originalPrice,
    required double interestAmount,
    required int months,
    required DateTime startDate,
  }) async {
    _validateId(saleId, 'saleId');

    final calculation = calculateInstallment(
      originalPrice: originalPrice,
      interestAmount: interestAmount,
      months: months,
    );

    await transaction(() async {
      final saleQuery = select(
        attachedDatabase.sales,
      )..where((sale) => sale.id.equals(saleId) & sale.isDeleted.equals(false));
      final sale = await saleQuery.getSingleOrNull();
      if (sale == null) {
        throw StateError('Active sale with ID $saleId was not found.');
      }

      final installmentsQuery = select(attachedDatabase.installments)
        ..where((installment) => installment.saleId.equals(saleId))
        ..orderBy([(installment) => OrderingTerm.asc(installment.monthNumber)]);
      final installments = await installmentsQuery.get();

      final installmentIds = installments
          .map((installment) => installment.id)
          .toList();
      final paymentInstallmentIds = <int>{};
      if (installmentIds.isNotEmpty) {
        final paymentsQuery = select(attachedDatabase.payments)
          ..where((payment) => payment.installmentId.isIn(installmentIds));
        final payments = await paymentsQuery.get();
        paymentInstallmentIds.addAll(
          payments.map((payment) => payment.installmentId),
        );
      }

      final installmentsByMonth = <int, Installment>{};
      for (final installment in installments) {
        final existing = installmentsByMonth[installment.monthNumber];
        if (existing != null) {
          throw StateError(
            'Sale $saleId has duplicate installment month '
            '${installment.monthNumber}.',
          );
        }
        installmentsByMonth[installment.monthNumber] = installment;
      }

      bool isProtected(Installment installment) {
        return installment.isPaid ||
            installment.totalPaid > 0 ||
            paymentInstallmentIds.contains(installment.id);
      }

      Installment? conflictingInstallment;
      for (final installment in installments) {
        if (installment.monthNumber > months && isProtected(installment)) {
          conflictingInstallment = installment;
          break;
        }
      }
      if (conflictingInstallment != null) {
        throw StateError(
          'Cannot reduce sale $saleId to $months months because installment '
          '${conflictingInstallment.monthNumber} has recorded payments.',
        );
      }

      final affectedRows =
          await (update(
            attachedDatabase.sales,
          )..where((sale) => sale.id.equals(saleId))).write(
            SalesCompanion(
              originalPrice: Value(originalPrice),
              interestAmount: Value(interestAmount),
              totalAmount: Value(calculation.totalAmount),
              months: Value(months),
              monthlyWithInterest: Value(calculation.monthlyWithInterest),
              monthlyWithoutInterest: Value(calculation.monthlyWithoutInterest),
              startDate: Value(startDate),
            ),
          );
      if (affectedRows != 1) {
        throw StateError('Sale $saleId could not be updated.');
      }

      for (final installment in installments) {
        if (isProtected(installment)) {
          continue;
        }

        if (installment.monthNumber > months) {
          await (delete(
            attachedDatabase.installments,
          )..where((row) => row.id.equals(installment.id))).go();
          continue;
        }

        await (update(
          attachedDatabase.installments,
        )..where((row) => row.id.equals(installment.id))).write(
          InstallmentsCompanion(
            dueDate: Value(
              _addCalendarMonths(startDate, installment.monthNumber),
            ),
            baseAmount: Value(calculation.monthlyWithInterest),
            carriedBalance: const Value(0),
            actualDue: Value(calculation.monthlyWithInterest),
          ),
        );
      }

      final missingInstallments = [
        for (var monthNumber = 1; monthNumber <= months; monthNumber++)
          if (!installmentsByMonth.containsKey(monthNumber))
            _newInstallment(
              saleId: saleId,
              monthNumber: monthNumber,
              startDate: startDate,
              monthlyAmount: calculation.monthlyWithInterest,
            ),
      ];
      if (missingInstallments.isNotEmpty) {
        await attachedDatabase.batch((batch) {
          batch.insertAll(attachedDatabase.installments, missingInstallments);
        });
      }
    });
  }

  Future<int> softDeleteSale(int saleId) async {
    _validateId(saleId, 'saleId');

    final affectedRows =
        await (update(attachedDatabase.sales)..where(
              (sale) => sale.id.equals(saleId) & sale.isDeleted.equals(false),
            ))
            .write(const SalesCompanion(isDeleted: Value(true)));
    if (affectedRows != 1) {
      throw StateError('Active sale with ID $saleId was not found.');
    }
    return affectedRows;
  }

  Future<int> restoreSale(int saleId) async {
    _validateId(saleId, 'saleId');

    final affectedRows =
        await (update(attachedDatabase.sales)..where(
              (sale) => sale.id.equals(saleId) & sale.isDeleted.equals(true),
            ))
            .write(const SalesCompanion(isDeleted: Value(false)));
    if (affectedRows != 1) {
      throw StateError('Deleted sale with ID $saleId was not found.');
    }
    return affectedRows;
  }

  Stream<List<Sale>> watchActiveSalesForCustomer(int customerId) {
    _validateId(customerId, 'customerId');

    final query = select(attachedDatabase.sales)
      ..where(
        (sale) =>
            sale.customerId.equals(customerId) & sale.isDeleted.equals(false),
      )
      ..orderBy([
        (sale) => OrderingTerm.desc(sale.startDate),
        (sale) => OrderingTerm.desc(sale.id),
      ]);

    return query.watch();
  }

  Stream<List<CustomerSaleDetails>> watchCustomerSales(int customerId) {
    _validateId(customerId, 'customerId');

    final query =
        select(attachedDatabase.sales).join([
            innerJoin(
              attachedDatabase.products,
              attachedDatabase.products.id.equalsExp(
                attachedDatabase.sales.productId,
              ),
            ),
            leftOuterJoin(
              attachedDatabase.installments,
              attachedDatabase.installments.saleId.equalsExp(
                attachedDatabase.sales.id,
              ),
            ),
          ])
          ..where(
            attachedDatabase.sales.customerId.equals(customerId) &
                attachedDatabase.sales.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm.desc(attachedDatabase.sales.startDate),
            OrderingTerm.desc(attachedDatabase.sales.id),
            OrderingTerm.asc(attachedDatabase.installments.monthNumber),
          ]);

    return query.watch().map((rows) {
      final sales = <int, Sale>{};
      final products = <int, Product>{};
      final installments = <int, List<Installment>>{};

      for (final row in rows) {
        final sale = row.readTable(attachedDatabase.sales);
        sales[sale.id] = sale;
        products[sale.id] = row.readTable(attachedDatabase.products);

        final installment = row.readTableOrNull(attachedDatabase.installments);
        if (installment != null) {
          (installments[sale.id] ??= []).add(installment);
        }
      }

      return [
        for (final entry in sales.entries)
          CustomerSaleDetails(
            sale: entry.value,
            product: products[entry.key]!,
            installments: List.unmodifiable(
              installments[entry.key] ?? const <Installment>[],
            ),
          ),
      ];
    });
  }

  InstallmentsCompanion _newInstallment({
    required int saleId,
    required int monthNumber,
    required DateTime startDate,
    required double monthlyAmount,
  }) {
    return InstallmentsCompanion.insert(
      saleId: saleId,
      monthNumber: monthNumber,
      dueDate: _addCalendarMonths(startDate, monthNumber),
      baseAmount: monthlyAmount,
      carriedBalance: 0,
      actualDue: monthlyAmount,
      totalPaid: 0,
      isPaid: const Value(false),
    );
  }

  DateTime _addCalendarMonths(DateTime date, int monthsToAdd) {
    final monthIndex = date.year * 12 + date.month - 1 + monthsToAdd;
    final targetYear = monthIndex ~/ 12;
    final targetMonth = monthIndex % 12 + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;

    if (date.isUtc) {
      return DateTime.utc(
        targetYear,
        targetMonth,
        targetDay,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      );
    }

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  Future<void> _ensureActiveCustomerExists(int customerId) async {
    final query = select(attachedDatabase.customers)
      ..where(
        (customer) =>
            customer.id.equals(customerId) & customer.isDeleted.equals(false),
      );
    if (await query.getSingleOrNull() == null) {
      throw StateError('Active customer with ID $customerId was not found.');
    }
  }

  Future<void> _ensureActiveProductExists(int productId) async {
    final query = select(attachedDatabase.products)
      ..where(
        (product) =>
            product.id.equals(productId) & product.isDeleted.equals(false),
      );
    if (await query.getSingleOrNull() == null) {
      throw StateError('Active product with ID $productId was not found.');
    }
  }

  void _validateId(int id, String name) {
    if (id <= 0) {
      throw ArgumentError.value(id, name, 'Must be greater than zero.');
    }
  }
}
