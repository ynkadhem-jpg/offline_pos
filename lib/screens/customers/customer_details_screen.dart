import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/payment_dao.dart';
import '../../services/product_dao.dart';
import '../../services/sale_dao.dart';
import '../widgets/app_ui.dart';
import 'add_product_dialog.dart';
import 'payment_dialog.dart';

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({
    required this.customer,
    required this.paymentDao,
    required this.productDao,
    required this.saleDao,
    required this.onDataChanged,
    super.key,
  });

  final Customer customer;
  final PaymentDao paymentDao;
  final ProductDao productDao;
  final SaleDao saleDao;
  final Future<void> Function() onDataChanged;

  Future<void> _showAddProduct(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => AddProductDialog(
        customerId: customer.id,
        productDao: productDao,
        saleDao: saleDao,
      ),
    );
    if (changed == true) {
      unawaited(onDataChanged());
    }
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
        onPaymentRecorded: onDataChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                sliver: SliverList.list(
                  children: [
                    AppPageHeader(
                      title: customer.name,
                      subtitle: 'تفاصيل الزبون، مشترياته، وجدول الأقساط.',
                      action: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('رجوع'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _showAddProduct(context),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('إضافة منتج'),
                          ),
                        ],
                      ),
                    ),
                    _CustomerHero(customer: customer),
                    const SizedBox(height: AppSpacing.lg),
                    StreamBuilder<List<CustomerSaleDetails>>(
                      stream: saleDao.watchCustomerSales(customer.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const AppPanel(
                            child: AppEmptyState(
                              icon: Icons.error_outline,
                              title: 'تعذر تحميل تفاصيل الزبون',
                              description:
                                  'حاول الرجوع وإعادة فتح صفحة الزبون مرة أخرى.',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final sales = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DetailsOverview(sales: sales),
                            const SizedBox(height: AppSpacing.lg),
                            AppSectionHeader(
                              title: 'المشتريات والأقساط',
                              subtitle:
                                  'كل عملية بيع مع الأقساط المرتبطة بها وحالة الدفع.',
                              icon: Icons.receipt_long_outlined,
                              action: AppStatusChip(
                                label: '${sales.length} عملية',
                                tone: AppStatusTone.info,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (sales.isEmpty)
                              AppPanel(
                                child: AppEmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'لا توجد مشتريات لهذا الزبون',
                                  description:
                                      'أضف أول منتج لإنشاء جدول أقساط واضح.',
                                  action: FilledButton.icon(
                                    onPressed: () => _showAddProduct(context),
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('إضافة منتج'),
                                  ),
                                ),
                              )
                            else
                              for (final details in sales) ...[
                                _SaleDetailsCard(
                                  details: details,
                                  onPay: (installment) =>
                                      _showPaymentDialog(context, installment),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerHero extends StatelessWidget {
  const _CustomerHero({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = customer.name.trim().isEmpty
        ? '؟'
        : customer.name.trim().substring(0, 1);

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Center(
              child: Text(
                initial,
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetaItem(
                      icon: Icons.phone_outlined,
                      text: customer.phone,
                    ),
                    _MetaItem(
                      icon: Icons.location_on_outlined,
                      text: customer.address,
                    ),
                    _MetaItem(
                      icon: Icons.calendar_today_outlined,
                      text: 'منذ ${_date(customer.createdAt)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsOverview extends StatelessWidget {
  const _DetailsOverview({required this.sales});

  final List<CustomerSaleDetails> sales;

  @override
  Widget build(BuildContext context) {
    final totalAmount = sales.fold<double>(
      0,
      (sum, details) => sum + details.sale.totalAmount,
    );
    final remainingAmount = sales.fold<double>(
      0,
      (sum, details) => sum + details.remainingAmount,
    );
    final installments = [
      for (final details in sales) ...details.installments,
    ];
    final paidInstallments = installments.where(_isPaid).length;
    final unpaidInstallments = installments.length - paidInstallments;

    return AppResponsiveWrap(
      wideColumns: 4,
      mediumColumns: 2,
      children: [
        AppMetricCard(
          icon: Icons.shopping_bag_outlined,
          label: 'عدد المشتريات',
          value: '${sales.length}',
          subtitle: 'عملية بيع',
          tone: AppStatusTone.info,
          compact: true,
        ),
        AppMetricCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'إجمالي المطلوب',
          value: _money(totalAmount),
          subtitle: 'قيمة كل المبيعات',
          tone: AppStatusTone.neutral,
          compact: true,
        ),
        AppMetricCard(
          icon: Icons.payments_outlined,
          label: 'المبلغ المتبقي',
          value: _money(remainingAmount),
          subtitle: 'غير مدفوع بعد',
          tone: AppStatusTone.warning,
          compact: true,
        ),
        AppMetricCard(
          icon: Icons.verified_outlined,
          label: 'الأقساط المدفوعة',
          value: '$paidInstallments / ${installments.length}',
          subtitle: unpaidInstallments == 0 ? 'كل الأقساط مكتملة' : 'متابعة',
          tone: unpaidInstallments == 0
              ? AppStatusTone.success
              : AppStatusTone.accent,
          compact: true,
        ),
      ],
    );
  }
}

class _SaleDetailsCard extends StatefulWidget {
  const _SaleDetailsCard({required this.details, required this.onPay});

  final CustomerSaleDetails details;
  final ValueChanged<Installment> onPay;

  @override
  State<_SaleDetailsCard> createState() => _SaleDetailsCardState();
}

class _SaleDetailsCardState extends State<_SaleDetailsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.details.sale;
    final installments = widget.details.installments;
    final paidInstallments = installments.where(_isPaid).length;
    final progress = installments.isEmpty
        ? 0.0
        : paidInstallments / installments.length;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.details.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'بدء التقسيط: ${_date(sale.startDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final amounts = _SaleAmounts(sale: sale, details: widget.details);

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.md),
                    amounts,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 4, child: title),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 5, child: amounts),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: AppColors.border,
              color: progress >= 1 ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusChip(
                label: '$paidInstallments من ${installments.length} مدفوع',
                icon: Icons.check_circle_outline,
                tone: progress >= 1
                    ? AppStatusTone.success
                    : AppStatusTone.info,
              ),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
                label: Text(_expanded ? 'إخفاء الأقساط' : 'عرض الأقساط'),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _InstallmentList(
                installments: installments,
                onPay: widget.onPay,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _SaleAmounts extends StatelessWidget {
  const _SaleAmounts({required this.sale, required this.details});

  final Sale sale;
  final CustomerSaleDetails details;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AmountTile(
            label: 'السعر الأصلي',
            value: _money(sale.originalPrice),
            icon: Icons.price_change_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AmountTile(
            label: 'الفائدة',
            value: _money(sale.interestAmount),
            icon: Icons.trending_up_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _AmountTile(
            label: 'المتبقي',
            value: _money(details.remainingAmount),
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }
}

class _InstallmentList extends StatelessWidget {
  const _InstallmentList({required this.installments, required this.onPay});

  final List<Installment> installments;
  final ValueChanged<Installment> onPay;

  @override
  Widget build(BuildContext context) {
    if (installments.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'لا توجد أقساط لهذه العملية',
        compact: true,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < installments.length; index++) ...[
          _InstallmentRow(
            installment: installments[index],
            onPay: onPay,
          ),
          if (index != installments.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.installment, required this.onPay});

  final Installment installment;
  final ValueChanged<Installment> onPay;

  @override
  Widget build(BuildContext context) {
    final paid = _isPaid(installment);
    final remaining = installment.actualDue - installment.totalPaid;
    final safeRemaining = remaining <= 0 ? 0.0 : remaining;
    final overdueDays = _overdueDays(installment);
    final tone = paid
        ? AppStatusTone.success
        : overdueDays > 0
            ? AppStatusTone.warning
            : AppStatusTone.info;
    final label = paid
        ? 'مدفوع'
        : overdueDays > 0
            ? 'متأخر $overdueDays يوم'
            : 'مستحق';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.rg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    '${installment.monthNumber}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قسط شهر ${_date(installment.dueDate)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'المتبقي ${_money(safeRemaining)} من ${_money(installment.actualDue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusChip(label: label, tone: tone),
              if (!paid)
                FilledButton.icon(
                  onPressed: () => onPay(installment),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسديد'),
                ),
            ],
          );

          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: AppSpacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.rg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.inkSoft),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

bool _isPaid(Installment installment) {
  return installment.isPaid || installment.totalPaid >= installment.actualDue;
}

int _overdueDays(Installment installment) {
  if (_isPaid(installment)) return 0;
  final today = DateUtils.dateOnly(DateTime.now());
  final dueDate = DateUtils.dateOnly(installment.dueDate);
  if (!dueDate.isBefore(today)) return 0;
  return today.difference(dueDate).inDays;
}

String _money(double value) {
  final currency = NumberFormat.decimalPattern('en');
  return '${currency.format(value)} د.ع';
}

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}
