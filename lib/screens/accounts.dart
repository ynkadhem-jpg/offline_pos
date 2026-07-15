import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/database.dart';
import '../services/reports_dao.dart';
import '../services/sales_report_dao.dart';
import 'widgets/app_ui.dart';

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
  int _visibleSalesLimit = 50;

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
      _visibleSalesLimit = 50;
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
      _visibleSalesLimit = 50;
      if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
        _fromDate = null;
      }
    });
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _visibleSalesLimit = 50;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _visibleSalesLimit = 50;
    });
  }

  void _showMoreSales() {
    setState(() => _visibleSalesLimit += 50);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<SalesReportRow> _filterSales(List<SalesReportRow> sales) {
    final query = _searchQuery.trim().toLowerCase();
    final from = _fromDate;
    final to = _toDate;
    final toExclusive = to == null
        ? null
        : DateTime(to.year, to.month, to.day + 1);

    return sales
        .where((sale) {
          final matchesSearch =
              query.isEmpty ||
              sale.customerName.toLowerCase().contains(query) ||
              sale.productName.toLowerCase().contains(query);
          final saleDate = sale.startDate;
          final matchesFrom = from == null || !saleDate.isBefore(from);
          final matchesTo =
              toExclusive == null || saleDate.isBefore(toExclusive);
          return matchesSearch && matchesFrom && matchesTo;
        })
        .toList(growable: false);
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
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'التقارير',
                subtitle: 'متابعة الأرباح والمبيعات والمنتجات الأكثر حركة.',
              ),
              _buildSummarySection(),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'المنتجات الأكثر مبيعاً',
                icon: Icons.workspace_premium_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTopProductsSection(),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(
                title: 'المبيعات',
                icon: Icons.receipt_long_outlined,
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
            final metrics = [
              AppMetricCard(
                icon: Icons.trending_up,
                label: 'الأرباح الصافية',
                value: _formatMoney(summary.totalProfit),
                subtitle: 'بعد احتساب الفائدة',
                tone: AppStatusTone.success,
                compact: true,
              ),
              AppMetricCard(
                icon: Icons.receipt_long_outlined,
                label: 'عدد المبيعات',
                value: '${summary.totalSales}',
                subtitle: 'عملية نشطة',
                tone: AppStatusTone.info,
                compact: true,
              ),
              AppMetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'المبالغ المتبقية',
                value: _formatMoney(summary.remainingBalance),
                subtitle: 'بانتظار التحصيل',
                tone: AppStatusTone.warning,
                compact: true,
              ),
            ];

            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeroCard(
                    label: 'إجمالي المبالغ المستحصلة',
                    value: _formatMoney(summary.totalCollected),
                    icon: Icons.payments_outlined,
                    subtitle: 'كل المدفوعات المسجلة على المبيعات النشطة.',
                    action: const AppStatusChip(
                      label: 'مباشر',
                      icon: Icons.bolt_outlined,
                      tone: AppStatusTone.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppResponsiveWrap(wideColumns: 3, children: metrics),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: AppHeroCard(
                    label: 'إجمالي المبالغ المستحصلة',
                    value: _formatMoney(summary.totalCollected),
                    icon: Icons.payments_outlined,
                    subtitle: 'كل المدفوعات المسجلة على المبيعات النشطة.',
                    action: const AppStatusChip(
                      label: 'تحديث مباشر',
                      icon: Icons.bolt_outlined,
                      tone: AppStatusTone.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 6,
                  child: AppResponsiveWrap(
                    wideColumns: 3,
                    mediumColumns: 3,
                    children: metrics,
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

        return AppPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              for (var index = 0; index < products.length; index++) ...[
                _TopProductRow(product: products[index], rank: index + 1),
                if (index < products.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    final hasDateFilter = _fromDate != null || _toDate != null;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الزبون أو المنتج',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          );
          final dateButtons = Wrap(
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
                  _toDate == null
                      ? 'إلى تاريخ'
                      : 'إلى: ${_formatDate(_toDate!)}',
                ),
              ),
              if (hasDateFilter)
                TextButton.icon(
                  onPressed: _clearDateRange,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('مسح التاريخ'),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: AppSpacing.sm),
                dateButtons,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: AppSpacing.md),
              dateButtons,
            ],
          );
        },
      ),
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

        final visibleSales = filteredSales.take(_visibleSalesLimit).toList();
        final groups = _groupSales(visibleSales);
        final hasMoreSales = visibleSales.length < filteredSales.length;
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
            if (hasMoreSales) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _showMoreSales,
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    'عرض المزيد (${filteredSales.length - visibleSales.length})',
                  ),
                ),
              ),
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

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product, required this.rank});

  final TopSellingProduct product;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLeader = rank == 1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.rg),
      decoration: BoxDecoration(
        color: isLeader
            ? AppColors.accentSoft.withValues(alpha: 0.58)
            : AppColors.surfaceMuted.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isLeader
              ? AppColors.accent.withValues(alpha: 0.20)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isLeader ? AppColors.accent : AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: textTheme.titleSmall?.copyWith(
                  color: isLeader ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.rg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (product.isDeleted) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'منتج محذوف',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppStatusChip(
            label: '${product.salesCount} مبيعات',
            icon: Icons.local_fire_department_outlined,
            tone: isLeader ? AppStatusTone.accent : AppStatusTone.neutral,
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.rg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sale.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppStatusChip(
                  label: sale.isFullyPaid ? 'مدفوع بالكامل' : 'نشط',
                  icon: sale.isFullyPaid
                      ? Icons.check_circle_outline
                      : Icons.schedule_outlined,
                  tone: sale.isFullyPaid
                      ? AppStatusTone.success
                      : AppStatusTone.info,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SaleValue(
                  label: 'السعر الأصلي',
                  value: money(sale.originalPrice),
                  icon: Icons.price_change_outlined,
                ),
                _SaleValue(
                  label: 'الفائدة',
                  value: money(sale.interestAmount),
                  icon: Icons.trending_up_outlined,
                ),
                _SaleValue(
                  label: 'المبلغ الكلي',
                  value: money(sale.totalAmount),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _SaleValue(
                  label: 'تاريخ البدء',
                  value: date(sale.startDate),
                  icon: Icons.calendar_today_outlined,
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
  const _SaleValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.rg),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: AppEmptyState(icon: icon, title: message),
    );
  }
}
