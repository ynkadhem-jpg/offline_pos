import 'package:drift/drift.dart';

import 'database.dart';

/// Read-only sale data prepared for the accounts report list.
class SalesReportRow {
  const SalesReportRow({
    required this.saleId,
    required this.customerName,
    required this.productName,
    required this.originalPrice,
    required this.interestAmount,
    required this.totalAmount,
    required this.startDate,
    required this.isFullyPaid,
  });

  final int saleId;
  final String customerName;
  final String productName;
  final double originalPrice;
  final double interestAmount;
  final double totalAmount;
  final DateTime startDate;
  final bool isFullyPaid;
}

class SalesReportDao extends DatabaseAccessor<AppDatabase> {
  SalesReportDao(super.db);

  /// Watches active sales with their referenced customer and product names.
  Stream<List<SalesReportRow>> watchActiveSales() {
    final query =
        select(attachedDatabase.sales).join([
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
            leftOuterJoin(
              attachedDatabase.installments,
              attachedDatabase.installments.saleId.equalsExp(
                attachedDatabase.sales.id,
              ),
            ),
          ])
          ..where(attachedDatabase.sales.isDeleted.equals(false))
          ..orderBy([
            OrderingTerm.desc(attachedDatabase.sales.startDate),
            OrderingTerm.desc(attachedDatabase.sales.id),
            OrderingTerm.asc(attachedDatabase.installments.id),
          ]);

    return query.watch().map((rows) {
      final sales = <int, Sale>{};
      final customerNames = <int, String>{};
      final productNames = <int, String>{};
      final hasInstallments = <int, bool>{};
      final allInstallmentsPaid = <int, bool>{};

      for (final row in rows) {
        final sale = row.readTable(attachedDatabase.sales);
        sales[sale.id] = sale;
        customerNames[sale.id] = row.readTable(attachedDatabase.customers).name;
        productNames[sale.id] = row.readTable(attachedDatabase.products).name;

        final installment = row.readTableOrNull(attachedDatabase.installments);
        if (installment != null) {
          hasInstallments[sale.id] = true;
          allInstallmentsPaid[sale.id] =
              (allInstallmentsPaid[sale.id] ?? true) && installment.isPaid;
        }
      }

      return [
        for (final sale in sales.values)
          SalesReportRow(
            saleId: sale.id,
            customerName: customerNames[sale.id]!,
            productName: productNames[sale.id]!,
            originalPrice: sale.originalPrice,
            interestAmount: sale.interestAmount,
            totalAmount: sale.totalAmount,
            startDate: sale.startDate,
            isFullyPaid:
                (hasInstallments[sale.id] ?? false) &&
                (allInstallmentsPaid[sale.id] ?? false),
          ),
      ];
    });
  }
}
