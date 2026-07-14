import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/payment_dao.dart';
import '../../services/product_dao.dart';
import '../../services/sale_dao.dart';
import 'add_product_dialog.dart';
import 'payment_dialog.dart';

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({
    required this.customer,
    required this.paymentDao,
    required this.productDao,
    required this.saleDao,
    super.key,
  });

  final Customer customer;
  final PaymentDao paymentDao;
  final ProductDao productDao;
  final SaleDao saleDao;

  Future<void> _showAddProductDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AddProductDialog(
        customerId: customer.id,
        productDao: productDao,
        saleDao: saleDao,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الزبون')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('المعلومات الأساسية', style: textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.lg),
                        _CustomerDetailRow(
                          icon: Icons.person_outline,
                          label: 'الاسم',
                          value: customer.name,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CustomerDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'العنوان',
                          value: customer.address,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CustomerDetailRow(
                          icon: Icons.phone_outlined,
                          label: 'رقم الهاتف',
                          value: customer.phone,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المنتجات المأخوذة',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddProductDialog(context),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('إضافة منتج'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _CustomerSalesSection(
                  customerId: customer.id,
                  paymentDao: paymentDao,
                  saleDao: saleDao,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerSalesSection extends StatefulWidget {
  const _CustomerSalesSection({
    required this.customerId,
    required this.paymentDao,
    required this.saleDao,
  });

  final int customerId;
  final PaymentDao paymentDao;
  final SaleDao saleDao;

  @override
  State<_CustomerSalesSection> createState() => _CustomerSalesSectionState();
}

class _CustomerSalesSectionState extends State<_CustomerSalesSection> {
  late final Stream<List<CustomerSaleDetails>> _salesStream;

  @override
  void initState() {
    super.initState();
    _salesStream = widget.saleDao.watchCustomerSales(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomerSaleDetails>>(
      stream: _salesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _SalesMessage(
            message: 'تعذر تحميل المنتجات المأخوذة',
          );
        }

        final sales = snapshot.data ?? [];
        if (sales.isEmpty) {
          return const _SalesMessage(
            message: 'لا توجد منتجات مضافة لهذا الزبون حالياً',
          );
        }

        return Column(
          children: [
            for (var index = 0; index < sales.length; index++) ...[
              _SaleCard(
                details: sales[index],
                paymentDao: widget.paymentDao,
              ),
              if (index != sales.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.details, required this.paymentDao});

  final CustomerSaleDetails details;
  final PaymentDao paymentDao;

  String _money(double value) {
    return '${NumberFormat.decimalPattern('en').format(value)} د.ع';
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}/$month/$day';
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    Installment installment,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => PaymentDialog(
        installment: installment,
        paymentDao: paymentDao,
      ),
    );
  }

  int _overdueDays(Installment installment) {
    if (installment.isPaid) {
      return 0;
    }

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final dueDate = DateTime.utc(
      installment.dueDate.year,
      installment.dueDate.month,
      installment.dueDate.day,
    );
    if (!dueDate.isBefore(today)) {
      return 0;
    }

    return today.difference(dueDate).inDays;
  }

  DataRow _installmentRow(BuildContext context, Installment installment) {
    final calculatedRemaining = installment.actualDue - installment.totalPaid;
    final remaining = calculatedRemaining > 0 ? calculatedRemaining : 0.0;
    final overdueDays = _overdueDays(installment);
    final colorScheme = Theme.of(context).colorScheme;

    return DataRow(
      color: overdueDays > 0
          ? WidgetStatePropertyAll(colorScheme.errorContainer)
          : null,
      cells: [
        DataCell(Text('${installment.monthNumber}')),
        DataCell(Text(_date(installment.dueDate))),
        DataCell(Text(_money(installment.actualDue))),
        DataCell(Text(_money(installment.totalPaid))),
        DataCell(Text(_money(remaining))),
        DataCell(
          overdueDays > 0
              ? Text(
                  'متأخر $overdueDays يوم',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(remaining == 0 ? 'مدفوع' : 'غير مدفوع'),
        ),
        DataCell(
          installment.isPaid
              ? const SizedBox.shrink()
              : FilledButton.tonalIcon(
                  onPressed: () => _showPaymentDialog(context, installment),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسجيل دفعة'),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = details.sale;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          details.product.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _SaleValue(
                label: 'السعر الأصلي',
                value: _money(sale.originalPrice),
              ),
              _SaleValue(
                label: 'الفائدة الثابتة',
                value: _money(sale.interestAmount),
              ),
              _SaleValue(
                label: 'المبلغ الكلي',
                value: _money(sale.totalAmount),
              ),
              _SaleValue(label: 'عدد الأشهر', value: '${sale.months}'),
              _SaleValue(
                label: 'المبلغ المتبقي',
                value: _money(details.remainingAmount),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: AppSpacing.xs),
          if (details.installments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.cardPadding),
              child: Text('لا توجد أقساط لهذه العملية'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الشهر')),
                  DataColumn(label: Text('تاريخ الاستحقاق')),
                  DataColumn(label: Text('المبلغ المستحق')),
                  DataColumn(label: Text('المبلغ المدفوع')),
                  DataColumn(label: Text('المبلغ المتبقي')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (final installment in details.installments)
                    _installmentRow(context, installment),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SaleValue extends StatelessWidget {
  const _SaleValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.xxl * 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _SalesMessage extends StatelessWidget {
  const _SalesMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CustomerDetailRow extends StatelessWidget {
  const _CustomerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
