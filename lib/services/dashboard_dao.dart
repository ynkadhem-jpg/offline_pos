import 'package:drift/drift.dart';

import 'database.dart';

/// Read-only installment data prepared specifically for dashboard widgets.
class DashboardInstallmentRow {
  const DashboardInstallmentRow({
    required this.installmentId,
    required this.saleId,
    required this.customerName,
    required this.productName,
    required this.dueDate,
    required this.actualDue,
    required this.totalPaid,
  });

  final int installmentId;
  final int saleId;
  final String customerName;
  final String productName;
  final DateTime dueDate;
  final double actualDue;
  final double totalPaid;

  double get remainingAmount {
    final remaining = actualDue - totalPaid;
    return remaining <= 0 ? 0 : remaining;
  }
}

class DashboardDao extends DatabaseAccessor<AppDatabase> {
  DashboardDao(super.db);

  /// Watches unpaid installments due on a specific local calendar day.
  Stream<List<DashboardInstallmentRow>> watchInstallmentsDueOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final query =
        select(attachedDatabase.installments).join([
            innerJoin(
              attachedDatabase.sales,
              attachedDatabase.sales.id.equalsExp(
                attachedDatabase.installments.saleId,
              ),
            ),
            innerJoin(
              attachedDatabase.customers,
              attachedDatabase.customers.id.equalsExp(
                attachedDatabase.sales.customerId,
              ),
            ),
            innerJoin(
              attachedDatabase.products,
              attachedDatabase.products.id.equalsExp(
                attachedDatabase.sales.productId,
              ),
            ),
          ])
          ..where(
            attachedDatabase.installments.isPaid.equals(false) &
                attachedDatabase.sales.isDeleted.equals(false) &
                attachedDatabase.installments.dueDate.isBiggerOrEqualValue(
                  start,
                ) &
                attachedDatabase.installments.dueDate.isSmallerThanValue(end),
          )
          ..orderBy([
            OrderingTerm.asc(attachedDatabase.installments.dueDate),
            OrderingTerm.asc(attachedDatabase.installments.id),
          ]);

    return query.watch().map(
      (rows) => rows
          .map((row) {
            final installment = row.readTable(attachedDatabase.installments);
            return DashboardInstallmentRow(
              installmentId: installment.id,
              saleId: installment.saleId,
              customerName: row.readTable(attachedDatabase.customers).name,
              productName: row.readTable(attachedDatabase.products).name,
              dueDate: installment.dueDate,
              actualDue: installment.actualDue,
              totalPaid: installment.totalPaid,
            );
          })
          .toList(growable: false),
    );
  }
}
