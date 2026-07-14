import 'package:drift/drift.dart';

import 'database.dart';

/// Derived report totals that are calculated on demand and never persisted.
class ReportSummary {
  const ReportSummary({
    required this.totalCollected,
    required this.totalProfit,
    required this.totalSales,
    required this.remainingBalance,
  });

  /// All amounts actually collected for active sales, including overpayments.
  final double totalCollected;

  /// The collected interest portion after capping each installment at its due.
  final double totalProfit;
  final int totalSales;
  final double remainingBalance;
}

/// A product ranked by its number of active sales.
class TopSellingProduct {
  const TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.salesCount,
    required this.isDeleted,
  });

  final int productId;
  final String productName;
  final int salesCount;
  final bool isDeleted;
}

class ReportsDao extends DatabaseAccessor<AppDatabase> {
  ReportsDao(super.db);

  /// Watches report totals derived from active sales and their installments.
  ///
  /// Collected interest is recognized proportionally using the current sale's
  /// interest-to-total ratio. Collected amounts are capped at each
  /// installment's due amount so overpayments cannot inflate profit. Because
  /// historical principal and interest allocations are not stored, financial
  /// edits to a sale can recalculate earlier profit using the current ratio.
  Stream<ReportSummary> watchSummary() {
    final query = customSelect(
      _summaryQuery,
      readsFrom: {
        attachedDatabase.sales,
        attachedDatabase.installments,
      },
    );

    return query.watchSingle().map(
      (row) => ReportSummary(
        totalCollected: row.read<double>('total_collected'),
        totalProfit: row.read<double>('total_profit'),
        totalSales: row.read<int>('total_sales'),
        remainingBalance: row.read<double>('remaining_balance'),
      ),
    );
  }

  /// Watches the five products with the most active sale rows.
  Stream<List<TopSellingProduct>> watchTopSellingProducts() {
    final query = customSelect(
      _topSellingProductsQuery,
      readsFrom: {
        attachedDatabase.sales,
        attachedDatabase.products,
      },
    );

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TopSellingProduct(
              productId: row.read<int>('product_id'),
              productName: row.read<String>('product_name'),
              salesCount: row.read<int>('sales_count'),
              isDeleted: row.read<int>('product_is_deleted') != 0,
            ),
          )
          .toList(growable: false),
    );
  }
}

const _summaryQuery = '''
SELECT
  (
    SELECT COUNT(*)
    FROM sales AS sale_count
    WHERE sale_count.is_deleted = 0
  ) AS total_sales,
  COALESCE(
    (
      SELECT SUM(
        CASE
          WHEN installment.actual_due > installment.total_paid
          THEN installment.actual_due - installment.total_paid
          ELSE 0.0
        END
      )
      FROM installments AS installment
      INNER JOIN sales AS remaining_sale
        ON remaining_sale.id = installment.sale_id
      WHERE remaining_sale.is_deleted = 0
    ),
    0.0
  ) AS remaining_balance,
  COALESCE(
    (
      SELECT SUM(installment.total_paid)
      FROM installments AS installment
      INNER JOIN sales AS collected_sale
        ON collected_sale.id = installment.sale_id
      WHERE collected_sale.is_deleted = 0
    ),
    0.0
  ) AS total_collected,
  COALESCE(
    (
      SELECT SUM(
        CASE
          WHEN profit_sale.total_amount > 0.0
            AND profit_sale.interest_amount > 0.0
            AND installment.actual_due > 0.0
            AND installment.total_paid > 0.0
          THEN
            CASE
              WHEN installment.total_paid < installment.actual_due
              THEN installment.total_paid
              ELSE installment.actual_due
            END
            * (profit_sale.interest_amount / profit_sale.total_amount)
          ELSE 0.0
        END
      )
      FROM installments AS installment
      INNER JOIN sales AS profit_sale
        ON profit_sale.id = installment.sale_id
      WHERE profit_sale.is_deleted = 0
    ),
    0.0
  ) AS total_profit
''';

const _topSellingProductsQuery = '''
SELECT
  product.id AS product_id,
  product.name AS product_name,
  product.is_deleted AS product_is_deleted,
  COUNT(sale.id) AS sales_count
FROM products AS product
INNER JOIN sales AS sale
  ON sale.product_id = product.id
  AND sale.is_deleted = 0
GROUP BY product.id, product.name, product.is_deleted
ORDER BY sales_count DESC, product.name ASC, product.id ASC
LIMIT 5
''';
