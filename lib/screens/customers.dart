import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/customer_dao.dart';
import '../services/customer_summary_dao.dart';
import '../services/database.dart';
import 'customers/customer_details_screen.dart';
import 'customers/customer_form_dialog.dart';

enum CustomerPaymentFilter { all, paidThisMonth, unpaidThisMonth }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final AppDatabase _db;
  late final CustomerDao _customerDao;
  late final CustomerSummaryDao _customerSummaryDao;
  late final Stream<List<CustomerSummary>> _customerSummariesStream;
  late final TextEditingController _searchController;

  String _searchQuery = '';
  CustomerPaymentFilter _paymentFilter = CustomerPaymentFilter.all;

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _customerDao = CustomerDao(_db);
    _customerSummaryDao = CustomerSummaryDao(_db);
    _customerSummariesStream =
        _customerSummaryDao.watchCustomerSummaries();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _db.close();
    super.dispose();
  }

  Stream<List<Customer>> _customersStream() {
    final query = _searchQuery.trim();
    return query.isEmpty
        ? _customerDao.watchCustomers()
        : _customerDao.searchCustomers(query);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _onPaymentFilterChanged(Set<CustomerPaymentFilter> selection) {
    if (selection.isEmpty) {
      return;
    }

    setState(() {
      _paymentFilter = selection.first;
    });
  }

  Future<void> _showAddCustomerForm() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => CustomerFormDialog(customerDao: _customerDao),
    );
  }

  Future<void> _showCustomerDetails(Customer customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CustomerDetailsScreen(customer: customer),
      ),
    );
  }

  void _handleQuickPayment(CustomerSummary summary) {
    if (!summary.hasCurrentMonthInstallment || summary.isCurrentMonthPaid) {
      return;
    }

    // TODO(task-4.1): Connect to PaymentDao when installment identifiers and
    // the full-payment API are available.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تفعيل الدفع السريع بعد إضافة خدمة الدفعات'),
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
        return summary.hasCurrentMonthInstallment &&
            summary.isCurrentMonthPaid;
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
      return 'لا يوجد زبائن';
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
      appBar: AppBar(title: const Text('الزبائن')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            _CustomerControls(
              searchController: _searchController,
              paymentFilter: _paymentFilter,
              onSearchChanged: _onSearchChanged,
              onPaymentFilterChanged: _onPaymentFilterChanged,
              onAddCustomer: _showAddCustomerForm,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: _customersStream(),
                builder: (context, customersSnapshot) {
                  if (customersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _CustomersMessage.loading();
                  }
                  if (customersSnapshot.hasError) {
                    return const _CustomersMessage(
                      message: 'حدث خطأ أثناء تحميل الزبائن',
                    );
                  }

                  final customers = customersSnapshot.data ?? [];
                  return StreamBuilder<List<CustomerSummary>>(
                    stream: _customerSummariesStream,
                    builder: (context, summariesSnapshot) {
                      if (summariesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const _CustomersMessage.loading();
                      }
                      if (summariesSnapshot.hasError) {
                        return const _CustomersMessage(
                          message: 'حدث خطأ أثناء تحميل ملخصات الزبائن',
                        );
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

                      if (visibleCustomers.isEmpty) {
                        return _CustomersMessage(
                          message: _emptyMessage(
                            hasActiveCustomers: customers.isNotEmpty,
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: visibleCustomers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final customer = visibleCustomers[index];
                          return _CustomerListItem(
                            customer: customer,
                            summary: _summaryFor(customer, summaries),
                            onQuickPayment: _handleQuickPayment,
                            onTap: () => _showCustomerDetails(customer),
                          );
                        },
                      );
                    },
                  );
                },
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
    required this.onAddCustomer,
  });

  final TextEditingController searchController;
  final CustomerPaymentFilter paymentFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<CustomerPaymentFilter>> onPaymentFilterChanged;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'بحث',
            hintText: 'ابحث باسم الزبون',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<CustomerPaymentFilter>(
              segments: const [
                ButtonSegment(
                  value: CustomerPaymentFilter.all,
                  label: Text('الكل'),
                ),
                ButtonSegment(
                  value: CustomerPaymentFilter.paidThisMonth,
                  label: Text('الدافعون هذا الشهر'),
                ),
                ButtonSegment(
                  value: CustomerPaymentFilter.unpaidThisMonth,
                  label: Text('غير الدافعين هذا الشهر'),
                ),
              ],
              selected: {paymentFilter},
              onSelectionChanged: onPaymentFilterChanged,
            ),
            FilledButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة زبون'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomerListItem extends StatelessWidget {
  const _CustomerListItem({
    required this.customer,
    required this.summary,
    required this.onQuickPayment,
    required this.onTap,
  });

  final Customer customer;
  final CustomerSummary summary;
  final ValueChanged<CustomerSummary> onQuickPayment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.decimalPattern('en');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final customerDetails = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(customer.name, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(customer.address, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(customer.phone, style: textTheme.bodyMedium),
                ],
              );
              final financialDetails = Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CustomerAmount(
                    label: 'إجمالي المطلوب',
                    value: '${currency.format(summary.totalOutstanding)} د.ع',
                  ),
                  _CustomerAmount(
                    label: 'قسط هذا الشهر',
                    value:
                        '${currency.format(summary.currentMonthInstallmentAmount)} د.ع',
                  ),
                  _CustomerStatus(summary: summary),
                  if (summary.hasCurrentMonthInstallment &&
                      !summary.isCurrentMonthPaid)
                    Tooltip(
                      message: 'تسديد قسط هذا الشهر',
                      child: OutlinedButton.icon(
                        onPressed: () => onQuickPayment(summary),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('تسديد قسط هذا الشهر'),
                      ),
                    ),
                ],
              );

              if (constraints.maxWidth < AppSpacing.xxl * 12) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    customerDetails,
                    const SizedBox(height: AppSpacing.md),
                    financialDetails,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: customerDetails),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: financialDetails),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerAmount extends StatelessWidget {
  const _CustomerAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textTheme.labelMedium),
        Text(value, style: textTheme.titleMedium),
      ],
    );
  }
}

class _CustomerStatus extends StatelessWidget {
  const _CustomerStatus({required this.summary});

  final CustomerSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, icon) = !summary.hasCurrentMonthInstallment
        ? ('لا يوجد قسط هذا الشهر', colorScheme.onSurfaceVariant, Icons.info)
        : summary.isCurrentMonthPaid
        ? ('مدفوع', AppColors.success, Icons.check_circle_outline)
        : ('غير مدفوع', colorScheme.error, Icons.error_outline);

    return Chip(
      avatar: Icon(icon, color: color),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      side: BorderSide(color: color),
    );
  }
}

class _CustomersMessage extends StatelessWidget {
  const _CustomersMessage({required this.message}) : isLoading = false;

  const _CustomersMessage.loading()
      : message = '',
        isLoading = true;

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoading
          ? const CircularProgressIndicator()
          : Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
    );
  }
}
