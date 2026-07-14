import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_spacing.dart';
import '../services/customer_dao.dart';
import '../services/database.dart';
import '../services/reports_dao.dart';
import '../services/sales_report_dao.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.database, super.key});

  final AppDatabase database;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<ReportSummary> _summaryStream;
  late final Stream<List<Customer>> _customersStream;
  late final Stream<List<SalesReportRow>> _salesStream;
  late final Stream<List<TopSellingProduct>> _topProductsStream;
  final NumberFormat _currency = NumberFormat.decimalPattern('en')
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 0;

  @override
  void initState() {
    super.initState();
    _summaryStream = ReportsDao(widget.database).watchSummary();
    _customersStream = CustomerDao(widget.database).watchCustomers();
    _salesStream = SalesReportDao(widget.database).watchActiveSales();
    _topProductsStream = ReportsDao(widget.database).watchTopSellingProducts();
  }

  String _money(double value) => '${_currency.format(value)} د.ع';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('لوحة التحكم')),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverList.list(
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: AppSpacing.lg),
                  _DashboardGrid(
                    children: [
                     /*  const DashboardSection(
                        title: 'الأقساط القادمة',
                        icon: Icons.event_available_outlined,
                        child: _UnavailableState(
                          icon: Icons.event_note_outlined,
                          message: 'لا تتوفر بيانات الأقساط القادمة حالياً',
                        ),
                      ),
                      const DashboardSection(
                        title: 'الأرباح خلال آخر 6 أشهر',
                        icon: Icons.show_chart,
                        child: _UnavailableState(
                          icon: Icons.query_stats,
                          message: 'لا تتوفر بيانات مجمّعة للرسم البياني حالياً',
                        ),
                      ), */
                      DashboardSection(
                        title: 'أحدث المبيعات',
                        icon: Icons.receipt_long_outlined,
                        child: _buildLatestSales(),
                      ),
                   /*    const DashboardSection(
                        title: 'توزيع حالة الأقساط',
                        icon: Icons.donut_large_outlined,
                        child: _UnavailableState(
                          icon: Icons.pie_chart_outline,
                          message: 'لا تتوفر بيانات مجمّعة لحالة الأقساط حالياً',
                        ),
                      ),
                      const DashboardSection(
                        title: 'ملخص مالي',
                        icon: Icons.account_balance_wallet_outlined,
                        child: _UnavailableState(
                          icon: Icons.summarize_outlined,
                          message: 'لا تتوفر إحصاءات اليوم حالياً',
                        ),
                      ), */
                      DashboardSection(
                        title: 'أكثر المنتجات مبيعاً',
                        icon: Icons.workspace_premium_outlined,
                        child: _buildTopProducts(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<ReportSummary>(
      stream: _summaryStream,
      builder: (context, summarySnapshot) {
        if (summarySnapshot.hasError) {
          return const _SectionError(message: 'تعذر تحميل ملخص لوحة التحكم');
        }
        if (!summarySnapshot.hasData) return const _SectionLoading();
        final summary = summarySnapshot.data!;
        return StreamBuilder<List<Customer>>(
          stream: _customersStream,
          builder: (context, customersSnapshot) {
            if (customersSnapshot.hasError) {
              return const _SectionError(message: 'تعذر تحميل عدد الزبائن');
            }
            if (!customersSnapshot.hasData) return const _SectionLoading();
            final cards = [
              _SummaryCard(
                icon: Icons.payments_outlined,
                title: 'إجمالي الأرباح',
                value: _money(summary.totalProfit),
              ),
              _SummaryCard(
                icon: Icons.shopping_cart_outlined,
                title: 'إجمالي المبيعات',
                value: '${summary.totalSales}',
                unit: 'مبيعة',
              ),
              _SummaryCard(
                icon: Icons.people_outline,
                title: 'إجمالي الزبائن',
                value: '${customersSnapshot.data!.length}',
                unit: 'زبون',
              ),
              _SummaryCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'المتبقي الكلي',
                value: _money(summary.remainingBalance),
              ),
            ];
            return _ResponsiveWrap(wideColumns: 4, children: cards);
          },
        );
      },
    );
  }

  Widget _buildLatestSales() {
    return StreamBuilder<List<SalesReportRow>>(
      stream: _salesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionError(message: 'تعذر تحميل أحدث المبيعات');
        }
        if (!snapshot.hasData) return const _SectionLoading();
        final sales = snapshot.data!.take(3).toList(growable: false);
        if (sales.isEmpty) {
          return const _UnavailableState(
            icon: Icons.receipt_long_outlined,
            message: 'لا توجد مبيعات حتى الآن',
          );
        }
        return Column(
          children: [
            for (var index = 0; index < sales.length; index++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.shopping_bag_outlined),
                ),
                title: Text(sales[index].customerName),
                subtitle: Text(sales[index].productName),
                trailing: Text(
                  _money(sales[index].totalAmount),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (index != sales.length - 1) const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTopProducts() {
    return StreamBuilder<List<TopSellingProduct>>(
      stream: _topProductsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionError(
            message: 'تعذر تحميل المنتجات الأكثر مبيعاً',
          );
        }
        if (!snapshot.hasData) return const _SectionLoading();
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const _UnavailableState(
            icon: Icons.inventory_2_outlined,
            message: 'لا توجد بيانات مبيعات للمنتجات حالياً',
          );
        }
        return Column(
          children: [
            for (var index = 0; index < products.length; index++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(products[index].productName),
                trailing: Text('${products[index].salesCount} مبيعة'),
              ),
              if (index != products.length - 1) const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _ResponsiveWrap(
    wideColumns: 3,
    mediumColumns: 2,
    children: children,
  );
}

class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({
    required this.children,
    required this.wideColumns,
    this.mediumColumns = 2,
  });

  final List<Widget> children;
  final int wideColumns;
  final int mediumColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? wideColumns
            : constraints.maxWidth >= 700
            ? mediumColumns
            : 1;
        final width =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class DashboardSection extends StatelessWidget {
  const DashboardSection({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xxl * 6,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    this.unit,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppSpacing.lg,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (unit != null)
                    Text(unit!, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: CircularProgressIndicator(),
    ),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => _UnavailableState(
    icon: Icons.error_outline,
    message: message,
    color: Theme.of(context).colorScheme.error,
  );
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({
    required this.icon,
    required this.message,
    this.color,
  });
  final IconData icon;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.xl, color: foreground),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
