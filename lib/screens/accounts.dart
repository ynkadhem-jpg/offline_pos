import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/database.dart';
import '../services/reports_dao.dart';
import '../services/sales_report_dao.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final AppDatabase _database;
  late final ReportsDao _reportsDao;
  late final SalesReportDao _salesReportDao;
  late final Stream<ReportSummary> _summaryStream;
  late final Stream<List<TopSellingProduct>> _topProductsStream;
  late final Stream<List<SalesReportRow>> _salesStream;
  late final TextEditingController _searchController;

  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _database = widget.database;
    _reportsDao = ReportsDao(_database);
    _salesReportDao = SalesReportDao(_database);
    _summaryStream = _reportsDao.watchSummary();
    _topProductsStream = _reportsDao.watchTopSellingProducts();
    _salesStream = _salesReportDao.watchActiveSales();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectFromDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ البداية',
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = _dateOnly(selectedDate);
      if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
        _toDate = null;
      }
    });
  }

  Future<void> _selectToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ النهاية',
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = _dateOnly(selectedDate);
      if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
        _fromDate = null;
      }
    });
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  List<SalesReportRow> _filterSales(List<SalesReportRow> sales) {
    final query = _searchQuery.trim().toLowerCase();
    final from = _fromDate;
    final to = _toDate;
    final toExclusive = to == null
        ? null
        : DateTime(to.year, to.month, to.day + 1);

    return sales.where((sale) {
      final matchesSearch =
          query.isEmpty ||
          sale.customerName.toLowerCase().contains(query) ||
          sale.productName.toLowerCase().contains(query);
      final saleDate = sale.startDate;
      final matchesFrom = from == null || !saleDate.isBefore(from);
      final matchesTo =
          toExclusive == null || saleDate.isBefore(toExclusive);
      return matchesSearch && matchesFrom && matchesTo;
    }).toList(growable: false);
  }

  Map<int, List<SalesReportRow>> _groupSales(List<SalesReportRow> sales) {
    final groups = <int, List<SalesReportRow>>{};
    for (final sale in sales) {
      final key = sale.startDate.year * 100 + sale.startDate.month;
      (groups[key] ??= []).add(sale);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ملخص الحسابات', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _buildSummarySection(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'المنتجات الأكثر مبيعاً',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTopProductsSection(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'المبيعات',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildFilters(),
              const SizedBox(height: AppSpacing.lg),
              _buildSalesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return StreamBuilder<ReportSummary>(
      stream: _summaryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionMessage(
            icon: Icons.error_outline,
            message: 'تعذر تحميل ملخص الحسابات',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    icon: Icons.trending_up,
                    label: 'الأرباح',
                    value: _formatMoney(summary.totalProfit),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'عدد المبيعات',
                    value: '${summary.totalSales}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'المبالغ المتبقية',
                    value: _formatMoney(summary.remainingBalance),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopProductsSection() {
    return StreamBuilder<List<TopSellingProduct>>(
      stream: _topProductsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionMessage(
            icon: Icons.error_outline,
            message: 'تعذر تحميل المنتجات الأكثر مبيعاً',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const _SectionMessage(
            icon: Icons.inventory_2_outlined,
            message: 'لا توجد بيانات مبيعات للمنتجات حالياً',
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              children: [
                for (var index = 0; index < products.length; index++) ...[
                  ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      products[index].productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: products[index].isDeleted
                        ? const Text('منتج محذوف')
                        : null,
                    trailing: Text('${products[index].salesCount} مبيعات'),
                  ),
                  if (index < products.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    final hasDateFilter = _fromDate != null || _toDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            labelText: 'بحث باسم الزبون أو المنتج',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _selectFromDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _fromDate == null
                    ? 'من تاريخ'
                    : 'من: ${_formatDate(_fromDate!)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectToDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _toDate == null ? 'إلى تاريخ' : 'إلى: ${_formatDate(_toDate!)}',
              ),
            ),
            if (hasDateFilter)
              TextButton.icon(
                onPressed: _clearDateRange,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('مسح التاريخ'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesSection() {
    return StreamBuilder<List<SalesReportRow>>(
      stream: _salesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionMessage(
            icon: Icons.error_outline,
            message: 'تعذر تحميل قائمة المبيعات',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const _SectionMessage(
            icon: Icons.receipt_long_outlined,
            message: 'لا توجد عمليات بيع حالياً',
          );
        }

        final filteredSales = _filterSales(snapshot.data!);
        if (filteredSales.isEmpty) {
          return const _SectionMessage(
            icon: Icons.search_off,
            message: 'لا توجد مبيعات مطابقة للبحث أو نطاق التاريخ',
          );
        }

        final groups = _groupSales(filteredSales);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  _formatMonth(entry.key),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final sale in entry.value) _SaleCard(sale: sale),
            ],
          ],
        );
      },
    );
  }

  String _formatMoney(double value) {
    final currency = NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 0;
    return '${currency.format(value)} د.ع';
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';

  String _formatMonth(int key) {
    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final year = key ~/ 100;
    final month = key % 100;
    return '${monthNames[month - 1]} $year';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final SalesReportRow sale;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 0;
    String money(double value) => '${currency.format(value)} د.ع';
    String date(DateTime value) =>
        '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    sale.customerName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    sale.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (sale.isFullyPaid) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(
                  avatar: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  label: const Text('مدفوع بالكامل'),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.success,
                  ),
                  side: const BorderSide(color: AppColors.success),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _SaleValue(
                  label: 'السعر الأصلي',
                  value: money(sale.originalPrice),
                ),
                _SaleValue(
                  label: 'الفائدة الثابتة',
                  value: money(sale.interestAmount),
                ),
                _SaleValue(
                  label: 'المبلغ الكلي',
                  value: money(sale.totalAmount),
                ),
                _SaleValue(
                  label: 'تاريخ البدء',
                  value: date(sale.startDate),
                ),
              ],
            ),
          ],
        ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
