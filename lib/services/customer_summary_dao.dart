import 'package:drift/drift.dart';

import 'database.dart';

class CustomerSummary {
  const CustomerSummary({
    required this.customerId,
    required this.totalOutstanding,
    required this.currentMonthInstallmentAmount,
    required this.isCurrentMonthPaid,
    required this.hasCurrentMonthInstallment,
  });

  final int customerId;
  final double totalOutstanding;
  final double currentMonthInstallmentAmount;
  final bool isCurrentMonthPaid;
  final bool hasCurrentMonthInstallment;
}

class CustomerSummaryDao extends DatabaseAccessor<AppDatabase> {
  CustomerSummaryDao(super.db);

  Stream<List<CustomerSummary>> watchCustomerSummaries({
    DateTime? referenceDate,
  }) {
    final localDate = referenceDate ?? DateTime.now();
    final monthStart = DateTime(localDate.year, localDate.month);
    final nextMonthStart = DateTime(localDate.year, localDate.month + 1);

    final query = customSelect(
      _customerSummariesQuery,
      variables: [
        Variable.withDateTime(monthStart),
        Variable.withDateTime(nextMonthStart),
      ],
      readsFrom: {
        attachedDatabase.customers,
        attachedDatabase.sales,
        attachedDatabase.installments,
      },
    );

    return query.watch().map(
      (rows) => rows.map((row) {
        final currentMonthInstallmentCount = row.read<int>(
          'current_month_installment_count',
        );
        final unpaidCurrentMonthInstallmentCount = row.read<int>(
          'unpaid_current_month_installment_count',
        );
        final hasCurrentMonthInstallment = currentMonthInstallmentCount > 0;

        return CustomerSummary(
          customerId: row.read<int>('customer_id'),
          totalOutstanding: row.read<double>('total_outstanding'),
          currentMonthInstallmentAmount: row.read<double>(
            'current_month_installment_amount',
          ),
          isCurrentMonthPaid:
              hasCurrentMonthInstallment &&
              unpaidCurrentMonthInstallmentCount == 0,
          hasCurrentMonthInstallment: hasCurrentMonthInstallment,
        );
      }).toList(),
    );
  }
}

const _customerSummariesQuery = '''
WITH month_bounds AS (
  SELECT ? AS month_start, ? AS next_month_start
)
SELECT
  c.id AS customer_id,
  COALESCE(
    SUM(
      CASE
        WHEN i.id IS NULL THEN 0.0
        WHEN i.is_paid = 1 OR i.total_paid >= i.actual_due THEN 0.0
        WHEN i.actual_due > i.total_paid THEN i.actual_due - i.total_paid
        ELSE 0.0
      END
    ),
    0.0
  ) AS total_outstanding,
  COALESCE(
    SUM(
      CASE
        WHEN i.due_date >= mb.month_start
          AND i.due_date < mb.next_month_start
        THEN i.actual_due
        ELSE 0.0
      END
    ),
    0.0
  ) AS current_month_installment_amount,
  COALESCE(
    SUM(
      CASE
        WHEN i.due_date >= mb.month_start
          AND i.due_date < mb.next_month_start
        THEN 1
        ELSE 0
      END
    ),
    0
  ) AS current_month_installment_count,
  COALESCE(
    SUM(
      CASE
        WHEN i.due_date >= mb.month_start
          AND i.due_date < mb.next_month_start
          AND NOT (i.is_paid = 1 OR i.total_paid >= i.actual_due)
        THEN 1
        ELSE 0
      END
    ),
    0
  ) AS unpaid_current_month_installment_count
FROM customers AS c
CROSS JOIN month_bounds AS mb
LEFT JOIN sales AS s
  ON s.customer_id = c.id
  AND s.is_deleted = 0
LEFT JOIN installments AS i
  ON i.sale_id = s.id
WHERE c.is_deleted = 0
GROUP BY c.id
ORDER BY c.name ASC
''';
