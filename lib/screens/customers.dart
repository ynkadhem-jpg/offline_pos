import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/customer_dao.dart';
import '../services/customer_summary_dao.dart';
import '../services/database.dart';
import '../services/payment_dao.dart';
import '../services/product_dao.dart';
import '../services/sale_dao.dart';
import 'customers/customer_details_screen.dart';
import 'customers/customer_form_dialog.dart';
import 'customers/payment_dialog.dart';
import 'widgets/app_ui.dart';

enum CustomerPaymentFilter { all, paidThisMonth, unpaidThisMonth }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    required this.database,
    required this.onDataChanged,
    super.key,
  });

  final AppDatabase database;
  final Future<void> Function() onDataChanged;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final AppDatabase _db;
  late final CustomerDao _customerDao;
  late final CustomerSummaryDao _customerSummaryDao;
  late final ProductDao _productDao;
  late final PaymentDao _paymentDao;
  late final SaleDao _saleDao;
  late final Stream<List<Customer>> _customersStream;
  late final Stream<List<CustomerSummary>> _customerSummariesStream;
  late final TextEditingController _searchController;

  String _searchQuery = '';
  CustomerPaymentFilter _paymentFilter = CustomerPaymentFilter.all;

  @override
  void initState() {
    super.initState();
    _db = widget.database;
    _customerDao = CustomerDao(_db);
    _customerSummaryDao = CustomerSummaryDao(_db);
    _productDao = ProductDao(_db);
    _paymentDao = PaymentDao(_db);
    _saleDao = SaleDao(_db);
    _customersStream = _customerDao.watchCustomers();
    _customerSummariesStream = _customerSummaryDao.watchCustomerSummaries();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final query = _searchQuery.trim();
    if (query.isEmpty) return customers;
    final normalizedQuery = query.toLowerCase();
    return customers
        .where((customer) {
          return customer.name.toLowerCase().contains(normalizedQuery) ||
              customer.phone.toLowerCase().contains(normalizedQuery) ||
              customer.address.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _onPaymentFilterChanged(CustomerPaymentFilter filter) {
    setState(() {
      _paymentFilter = filter;
    });
  }

  Future<void> _showAddCustomerForm() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => CustomerFormDialog(customerDao: _customerDao),
    );
    if (changed == true) {
      unawaited(widget.onDataChanged());
    }
  }

  Future<void> _showCustomerDetails(Customer customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CustomerDetailsScreen(
          customer: customer,
          paymentDao: _paymentDao,
          productDao: _productDao,
          saleDao: _saleDao,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  Future<void> _handleQuickPayment(Customer customer) async {
    try {
      final sales = await _saleDao.watchCustomerSales(customer.id).first;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);
      final nextMonthStart = DateTime(now.year, now.month + 1);
      final currentInstallments = <({Installment installment, String product})>[
        for (final details in sales)
          for (final installment in details.installments)
            if (!installment.dueDate.isBefore(monthStart) &&
                installment.dueDate.isBefore(nextMonthStart) &&
                !installment.isPaid &&
                installment.totalPaid < installment.actualDue)
              (installment: installment, product: details.product.name),
      ];

      if (!context.mounted) {
        return;
      }
      if (currentInstallments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد قسط غير مدفوع لهذا الشهر')),
        );
        return;
      }

      final selected = currentInstallments.length == 1
          ? currentInstallments.single.installment
          : await _selectCurrentInstallment(currentInstallments);
      if (selected == null || !context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => PaymentDialog(
          installment: selected,
          paymentDao: _paymentDao,
          onPaymentRecorded: widget.onDataChanged,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل قسط هذا الشهر: $error')),
      );
    }
  }

  Future<Installment?> _selectCurrentInstallment(
    List<({Installment installment, String product})> installments,
  ) {
    final currency = NumberFormat.decimalPattern('en');
    return showDialog<Installment>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر القسط المراد تسديده'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in installments) ...[
                InkWell(
                  onTap: () => Navigator.of(context).pop(entry.installment),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AppListCard(
                    leading: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.accent,
                    ),
                    title: entry.product,
                    subtitle:
                        '${currency.format(entry.installment.actualDue - entry.installment.totalPaid)} د.ع متبقي',
                    tone: AppStatusTone.accent,
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  CustomerSummary _summaryFor(
    Customer customer,
    Map<int, CustomerSummary> summaries,
  ) {
    return summaries[customer.id] ??
        CustomerSummary(
          customerId: customer.id,
          totalOutstanding: 0,
          currentMonthInstallmentAmount: 0,
          isCurrentMonthPaid: false,
          hasCurrentMonthInstallment: false,
        );
  }

  bool _matchesPaymentFilter(CustomerSummary summary) {
    switch (_paymentFilter) {
      case CustomerPaymentFilter.all:
        return true;
      case CustomerPaymentFilter.paidThisMonth:
        return summary.hasCurrentMonthInstallment && summary.isCurrentMonthPaid;
      case CustomerPaymentFilter.unpaidThisMonth:
        return summary.hasCurrentMonthInstallment &&
            !summary.isCurrentMonthPaid;
    }
  }

  String _emptyMessage({required bool hasActiveCustomers}) {
    if (_searchQuery.trim().isNotEmpty) {
      return 'لا توجد نتائج مطابقة للبحث';
    }
    if (!hasActiveCustomers) {
      return 'لا يوجد زبائن بعد';
    }
    if (_paymentFilter == CustomerPaymentFilter.paidThisMonth) {
      return 'لا يوجد زبائن دافعون هذا الشهر';
    }
    if (_paymentFilter == CustomerPaymentFilter.unpaidThisMonth) {
      return 'لا يوجد زبائن غير دافعين هذا الشهر';
    }
    return 'لا يوجد زبائن';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'الزبائن',
                subtitle:
                    'إدارة العلاقات، متابعة الاستحقاقات، وتسجيل الدفعات بثقة.',
                action: FilledButton.icon(
                  onPressed: _showAddCustomerForm,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('إضافة زبون'),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Customer>>(
                  stream: _customersStream,
                  builder: (context, customersSnapshot) {
                    if (customersSnapshot.hasError) {
                      return const _CustomersMessage(
                        icon: Icons.error_outline,
                        title: 'حدث خطأ أثناء تحميل الزبائن',
                        description: 'حاول إعادة فتح الشاشة أو التطبيق.',
                      );
                    }
                    if (!customersSnapshot.hasData) {
                      return const _CustomersMessage.loading();
                    }

                    final allCustomers = customersSnapshot.data ?? [];
                    final customers = _filterCustomers(allCustomers);
                    return StreamBuilder<List<CustomerSummary>>(
                      stream: _customerSummariesStream,
                      builder: (context, summariesSnapshot) {
                        if (summariesSnapshot.hasError) {
                          return const _CustomersMessage(
                            icon: Icons.error_outline,
                            title: 'حدث خطأ أثناء تحميل ملخصات الزبائن',
                            description:
                                'البيانات الأساسية سليمة، لكن الملخص تعذر تحميله.',
                          );
                        }
                        if (!summariesSnapshot.hasData) {
                          return const _CustomersMessage.loading();
                        }

                        final summaries = <int, CustomerSummary>{
                          for (final summary in summariesSnapshot.data ?? [])
                            summary.customerId: summary,
                        };
                        final visibleCustomers = customers.where((customer) {
                          return _matchesPaymentFilter(
                            _summaryFor(customer, summaries),
                          );
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CustomerOverview(
                              totalCustomers: allCustomers.length,
                              visibleCustomers: visibleCustomers.length,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _CustomerControls(
                              searchController: _searchController,
                              paymentFilter: _paymentFilter,
                              onSearchChanged: _onSearchChanged,
                              onPaymentFilterChanged: _onPaymentFilterChanged,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(
                              child: visibleCustomers.isEmpty
                                  ? _CustomersMessage(
                                      icon: Icons.people_outline,
                                      title: _emptyMessage(
                                        hasActiveCustomers:
                                            allCustomers.isNotEmpty,
                                      ),
                                      description:
                                          'يمكنك تعديل البحث أو تغيير الفلتر لعرض نتائج أخرى.',
                                      action: allCustomers.isEmpty
                                          ? FilledButton.icon(
                                              onPressed: _showAddCustomerForm,
                                              icon: const Icon(
                                                Icons.person_add_alt_1,
                                              ),
                                              label: const Text(
                                                'إضافة أول زبون',
                                              ),
                                            )
                                          : null,
                                    )
                                  : ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: visibleCustomers.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: AppSpacing.md),
                                      itemBuilder: (context, index) {
                                        final customer =
                                            visibleCustomers[index];
                                        return _CustomerCard(
                                          customer: customer,
                                          summary: _summaryFor(
                                            customer,
                                            summaries,
                                          ),
                                          onQuickPayment: _handleQuickPayment,
                                          onTap: () =>
                                              _showCustomerDetails(customer),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerOverview extends StatelessWidget {
  const _CustomerOverview({
    required this.totalCustomers,
    required this.visibleCustomers,
  });

  final int totalCustomers;
  final int visibleCustomers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showVisibleCount = visibleCustomers != totalCustomers;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.rg,
          vertical: AppSpacing.sm,
        ),
        backgroundColor: AppColors.surfaceCard.withValues(alpha: 0.72),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                size: 17,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              showVisibleCount ? 'المعروض' : 'مجموع الزبائن',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              showVisibleCount
                  ? '$visibleCustomers / $totalCustomers'
                  : '$totalCustomers',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerControls extends StatelessWidget {
  const _CustomerControls({
    required this.searchController,
    required this.paymentFilter,
    required this.onSearchChanged,
    required this.onPaymentFilterChanged,
  });

  final TextEditingController searchController;
  final CustomerPaymentFilter paymentFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CustomerPaymentFilter> onPaymentFilterChanged;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = SizedBox(
            width: constraints.maxWidth >= 720 ? 360 : double.infinity,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'ابحث باسم الزبون',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          );
          final filters = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppFilterPill(
                label: 'الكل',
                icon: Icons.people_outline,
                selected: paymentFilter == CustomerPaymentFilter.all,
                onTap: () => onPaymentFilterChanged(CustomerPaymentFilter.all),
              ),
              AppFilterPill(
                label: 'الدافعون هذا الشهر',
                icon: Icons.check_circle_outline,
                selected: paymentFilter == CustomerPaymentFilter.paidThisMonth,
                tone: AppStatusTone.success,
                onTap: () =>
                    onPaymentFilterChanged(CustomerPaymentFilter.paidThisMonth),
              ),
              AppFilterPill(
                label: 'غير الدافعين',
                icon: Icons.error_outline,
                selected:
                    paymentFilter == CustomerPaymentFilter.unpaidThisMonth,
                tone: AppStatusTone.warning,
                onTap: () => onPaymentFilterChanged(
                  CustomerPaymentFilter.unpaidThisMonth,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 820) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: AppSpacing.md),
                filters,
              ],
            );
          }

          return Row(
            children: [
              search,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: filters),
            ],
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.summary,
    required this.onQuickPayment,
    required this.onTap,
  });

  final Customer customer;
  final CustomerSummary summary;
  final ValueChanged<Customer> onQuickPayment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.decimalPattern('en');
    final canPay =
        summary.hasCurrentMonthInstallment && !summary.isCurrentMonthPaid;

    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final header = Row(
                children: [
                  _CustomerAvatar(name: customer.name),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _CustomerMeta(
                              icon: Icons.phone_outlined,
                              text: customer.phone,
                            ),
                            _CustomerMeta(
                              icon: Icons.location_on_outlined,
                              text: customer.address,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _CustomerStatus(summary: summary),
                ],
              );
              final financial = _CustomerAmounts(
                totalOutstanding:
                    '${currency.format(summary.totalOutstanding)} د.ع',
                currentMonth:
                    '${currency.format(summary.currentMonthInstallmentAmount)} د.ع',
              );
              final actions = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (canPay)
                    FilledButton.icon(
                      onPressed: () => onQuickPayment(customer),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('تسديد القسط'),
                    ),
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('التفاصيل'),
                  ),
                ],
              );

              if (constraints.maxWidth < 780) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.md),
                    financial,
                    const SizedBox(height: AppSpacing.md),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: header),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 4, child: financial),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(flex: 2, child: actions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty ? '؟' : trimmedName.substring(0, 1);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CustomerMeta extends StatelessWidget {
  const _CustomerMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.inkSoft),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CustomerAmounts extends StatelessWidget {
  const _CustomerAmounts({
    required this.totalOutstanding,
    required this.currentMonth,
  });

  final String totalOutstanding;
  final String currentMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CustomerAmount(
            label: 'إجمالي المطلوب',
            value: totalOutstanding,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CustomerAmount(
            label: 'قسط هذا الشهر',
            value: currentMonth,
            icon: Icons.calendar_month_outlined,
          ),
        ),
      ],
    );
  }
}

class _CustomerAmount extends StatelessWidget {
  const _CustomerAmount({
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatus extends StatelessWidget {
  const _CustomerStatus({required this.summary});

  final CustomerSummary summary;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = !summary.hasCurrentMonthInstallment
        ? ('لا يوجد قسط', AppStatusTone.neutral, Icons.info_outline)
        : summary.isCurrentMonthPaid
        ? ('مدفوع', AppStatusTone.success, Icons.check_circle_outline)
        : ('غير مدفوع', AppStatusTone.warning, Icons.error_outline);

    return AppStatusChip(label: label, tone: tone, icon: icon);
  }
}

class _CustomersMessage extends StatelessWidget {
  const _CustomersMessage({
    required this.icon,
    required this.title,
    this.description,
    this.action,
  }) : isLoading = false;

  const _CustomersMessage.loading()
    : icon = Icons.people_outline,
      title = '',
      description = null,
      action = null,
      isLoading = true;

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : AppPanel(
            child: AppEmptyState(
              icon: icon,
              title: title,
              description: description,
              action: action,
              compact: true,
            ),
          );
  }
}
