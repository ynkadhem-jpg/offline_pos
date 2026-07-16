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

class SalesStatusCounts {
  const SalesStatusCounts({required this.paid, required this.active});

  final int paid;
  final int active;

  int get total => paid + active;
}

class MonthlySalesTotal {
  const MonthlySalesTotal({
    required this.year,
    required this.month,
    required this.totalAmount,
  });

  final int year;
  final int month;
  final double totalAmount;
}

class SalesReportDao extends DatabaseAccessor<AppDatabase> {
  SalesReportDao(super.db);

  /// Watches active sales with their referenced customer and product names.
  Stream<List<SalesReportRow>> watchActiveSales() {
    return _watchSales(_activeSalesQuery);
  }

  Stream<List<SalesReportRow>> watchRecentActiveSales({int limit = 4}) {
    final query = customSelect(
      '$_activeSalesQuery LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {
        attachedDatabase.sales,
        attachedDatabase.customers,
        attachedDatabase.products,
        attachedDatabase.installments,
      },
    );

    return query.watch().map(_mapSalesRows);
  }

  Stream<SalesStatusCounts> watchSalesStatusCounts() {
    final query = customSelect(
      _salesStatusCountsQuery,
      readsFrom: {attachedDatabase.sales, attachedDatabase.installments},
    );

    return query.watchSingle().map(
      (row) => SalesStatusCounts(
        paid: row.read<int>('paid_count'),
        active: row.read<int>('active_count'),
      ),
    );
  }

  Stream<List<MonthlySalesTotal>> watchMonthlySalesTotals({
    required DateTime fromInclusive,
  }) {
    final start = DateTime(fromInclusive.year, fromInclusive.month);
    final query = customSelect(
      _monthlySalesTotalsQuery,
      variables: [Variable.withDateTime(start)],
      readsFrom: {attachedDatabase.sales},
    );

    return query.watch().map((rows) {
      final buckets = <int, double>{};

      for (final row in rows) {
        final startDate = row.read<DateTime>('start_date');
        final key = startDate.year * 100 + startDate.month;
        buckets[key] = (buckets[key] ?? 0) + row.read<double>('total_amount');
      }

      final totals =
          [
            for (final entry in buckets.entries)
              MonthlySalesTotal(
                year: entry.key ~/ 100,
                month: entry.key % 100,
                totalAmount: entry.value,
              ),
          ]..sort((a, b) {
            final byYear = a.year.compareTo(b.year);
            if (byYear != 0) return byYear;
            return a.month.compareTo(b.month);
          });

      return totals;
    });
  }

  Stream<List<SalesReportRow>> _watchSales(String sql) {
    final query = customSelect(
      sql,
      readsFrom: {
        attachedDatabase.sales,
        attachedDatabase.customers,
        attachedDatabase.products,
        attachedDatabase.installments,
      },
    );

    return query.watch().map(_mapSalesRows);
  }

  List<SalesReportRow> _mapSalesRows(List<QueryRow> rows) {
    return rows
        .map(
          (row) => SalesReportRow(
            saleId: row.read<int>('sale_id'),
            customerName: row.read<String>('customer_name'),
            productName: row.read<String>('product_name'),
            originalPrice: row.read<double>('original_price'),
            interestAmount: row.read<double>('interest_amount'),
            totalAmount: row.read<double>('total_amount'),
            startDate: row.read<DateTime>('start_date'),
            isFullyPaid: row.read<int>('is_fully_paid') != 0,
          ),
        )
        .toList(growable: false);
  }
}

const _activeSalesQuery = '''
SELECT
  sale.id AS sale_id,
  customer.name AS customer_name,
  product.name AS product_name,
  sale.original_price AS original_price,
  sale.interest_amount AS interest_amount,
  sale.total_amount AS total_amount,
  sale.start_date AS start_date,
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM installments AS installment_exists
      WHERE installment_exists.sale_id = sale.id
    )
    AND NOT EXISTS (
      SELECT 1
      FROM installments AS unpaid_installment
      WHERE unpaid_installment.sale_id = sale.id
        AND unpaid_installment.is_paid = 0
    )
    THEN 1
    ELSE 0
  END AS is_fully_paid
FROM sales AS sale
INNER JOIN customers AS customer
  ON customer.id = sale.customer_id
INNER JOIN products AS product
  ON product.id = sale.product_id
WHERE sale.is_deleted = 0
ORDER BY sale.start_date DESC, sale.id DESC
''';

const _salesStatusCountsQuery = '''
WITH sale_status AS (
  SELECT
    sale.id,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM installments AS installment_exists
        WHERE installment_exists.sale_id = sale.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM installments AS unpaid_installment
        WHERE unpaid_installment.sale_id = sale.id
          AND unpaid_installment.is_paid = 0
      )
      THEN 1
      ELSE 0
    END AS is_fully_paid
  FROM sales AS sale
  WHERE sale.is_deleted = 0
)
SELECT
  COALESCE(SUM(CASE WHEN is_fully_paid = 1 THEN 1 ELSE 0 END), 0) AS paid_count,
  COALESCE(SUM(CASE WHEN is_fully_paid = 0 THEN 1 ELSE 0 END), 0) AS active_count
FROM sale_status
''';

const _monthlySalesTotalsQuery = '''
SELECT
  sale.start_date AS start_date,
  sale.total_amount AS total_amount
FROM sales AS sale
WHERE sale.is_deleted = 0
  AND sale.start_date >= ?
ORDER BY sale.start_date ASC, sale.id ASC
''';
