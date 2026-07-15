import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/customer_dao.dart';
import '../services/dashboard_dao.dart';
import '../services/database.dart';
import '../services/reports_dao.dart';
import '../services/sales_report_dao.dart';
import 'widgets/app_ui.dart';

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
  late final Stream<List<DashboardInstallmentRow>> _todayInstallmentsStream;
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
    _todayInstallmentsStream = DashboardDao(
      widget.database,
    ).watchInstallmentsDueOn(DateTime.now());
  }

  String _money(double value) => '${_currency.format(value)} د.ع';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverList.list(
                children: [
                  const AppPageHeader(
                    title: 'لوحة التحكم',
                    subtitle: 'مركز مالي سريع يوضح التحصيل، الربح، وحركة البيع.',
                  ),
                  _buildSummaryArea(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildInsightsArea(),
                  const SizedBox(height: AppSpacing.lg),
                  _DashboardGrid(
                    children: [
                      DashboardSection(
                        title: 'أقساط اليوم',
                        subtitle: 'الأقساط غير المدفوعة المستحقة اليوم.',
                        icon: Icons.event_available_outlined,
                        child: _buildTodayInstallments(),
                      ),
                      DashboardSection(
                        title: 'أحدث المبيعات',
                        subtitle: 'آخر العمليات المسجلة في النظام.',
                        icon: Icons.receipt_long_outlined,
                        child: _buildLatestSales(),
                      ),
                      DashboardSection(
                        title: 'أكثر المنتجات مبيعاً',
                        subtitle: 'ترتيب مختصر حسب عدد المبيعات.',
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

  Widget _buildSummaryArea() {
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

            final metricCards = [
              AppMetricCard(
                icon: Icons.trending_up_outlined,
                label: 'صافي الربح',
                value: _money(summary.totalProfit),
                subtitle: 'بعد احتساب الفائدة',
                tone: AppStatusTone.success,
              ),
              AppMetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'المتبقي الكلي',
                value: _money(summary.remainingBalance),
                subtitle: 'مبالغ قيد التحصيل',
                tone: AppStatusTone.warning,
              ),
              AppMetricCard(
                icon: Icons.shopping_bag_outlined,
                label: 'إجمالي المبيعات',
                value: '${summary.totalSales}',
                subtitle: 'عملية بيع',
                tone: AppStatusTone.info,
              ),
              AppMetricCard(
                icon: Icons.groups_2_outlined,
                label: 'إجمالي الزبائن',
                value: '${customersSnapshot.data!.length}',
                subtitle: 'زبون نشط أو سابق',
                tone: AppStatusTone.accent,
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final hero = SizedBox(
                  height: isWide ? 214 : 220,
                  child: AppHeroCard(
                    icon: Icons.payments_outlined,
                    label: 'إجمالي المبالغ المستحصلة',
                    value: _money(summary.totalCollected),
                    subtitle:
                        'المبالغ المقبوضة بصورة عامة من كل عمليات التقسيط.',
                    action: const AppStatusChip(
                      label: 'تحديث مباشر',
                      tone: AppStatusTone.accent,
                      icon: Icons.bolt_outlined,
                    ),
                  ),
                );

                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hero,
                      const SizedBox(height: AppSpacing.md),
                      _ResponsiveWrap(wideColumns: 2, children: metricCards),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: hero),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 6,
                      child: _ResponsiveWrap(
                        wideColumns: 2,
                        mediumColumns: 2,
                        children: metricCards,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInsightsArea() {
    return StreamBuilder<List<SalesReportRow>>(
      stream: _salesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionError(message: 'تعذر تحميل مؤشرات المبيعات');
        }
        if (!snapshot.hasData) return const _SectionLoading();

        final sales = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final chart = _SalesChartCard(points: _monthlySales(sales));
            final donut = _SalesStatusCard(sales: sales);

            if (!isWide) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: AppSpacing.md),
                  donut,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: chart),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 5, child: donut),
              ],
            );
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

        final sales = snapshot.data!.take(4).toList(growable: false);
        if (sales.isEmpty) {
          return const AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد مبيعات حتى الآن',
            compact: true,
          );
        }

        return _ListStack(
          children: [
            for (final sale in sales)
              AppListCard(
                leading: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                ),
                title: sale.customerName,
                subtitle: sale.productName,
                tone: sale.isFullyPaid
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(sale.totalAmount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppStatusChip(
                      label: sale.isFullyPaid ? 'مكتملة' : 'نشطة',
                      tone: sale.isFullyPaid
                          ? AppStatusTone.success
                          : AppStatusTone.info,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTodayInstallments() {
    return StreamBuilder<List<DashboardInstallmentRow>>(
      stream: _todayInstallmentsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionError(message: 'تعذر تحميل أقساط اليوم');
        }
        if (!snapshot.hasData) return const _SectionLoading();

        final installments = snapshot.data!.take(4).toList(growable: false);
        if (installments.isEmpty) {
          return const AppEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'لا توجد أقساط مستحقة اليوم',
            description: 'كل شيء هادئ اليوم — لا توجد دفعات بانتظار التحصيل.',
            compact: true,
          );
        }

        return _ListStack(
          children: [
            for (final installment in installments)
              AppListCard(
                leading: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.accent,
                ),
                title: installment.customerName,
                subtitle: installment.productName,
                tone: AppStatusTone.accent,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(installment.remainingAmount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const AppStatusChip(
                      label: 'مستحق',
                      tone: AppStatusTone.accent,
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ),
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

        final products = snapshot.data!.take(5).toList(growable: false);
        if (products.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'لا توجد بيانات مبيعات للمنتجات حالياً',
            compact: true,
          );
        }

        final maxSales = products
            .map((product) => product.salesCount)
            .fold<int>(0, math.max);

        return _ListStack(
          children: [
            for (var index = 0; index < products.length; index++)
              _ProductRankCard(
                rank: index + 1,
                product: products[index],
                maxSales: maxSales,
              ),
          ],
        );
      },
    );
  }

  List<_MonthlySalesPoint> _monthlySales(List<SalesReportRow> sales) {
    final now = DateTime.now();
    final buckets = <_MonthKey, double>{};

    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      buckets[_MonthKey(month.year, month.month)] = 0;
    }

    for (final sale in sales) {
      final key = _MonthKey(sale.startDate.year, sale.startDate.month);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + sale.totalAmount;
      }
    }

    return [
      for (final entry in buckets.entries)
        _MonthlySalesPoint(
          label: _arabicMonth(entry.key.month),
          value: entry.value,
        ),
    ];
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
    this.subtitle,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 314, child: child),
        ],
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.points});

  final List<_MonthlySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final total = points.fold<double>(0, (sum, point) => sum + point.value);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'اتجاه المبيعات',
            subtitle: 'إجمالي قيمة المبيعات خلال آخر ستة أشهر.',
            icon: Icons.show_chart_outlined,
            action: AppStatusChip(
              label: total == 0 ? 'بانتظار بيانات' : 'آخر 6 أشهر',
              tone: total == 0 ? AppStatusTone.warning : AppStatusTone.info,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 260,
            child: total == 0
                ? const AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'لا توجد مبيعات كافية للرسم البياني',
                    compact: true,
                  )
                : CustomPaint(
                    painter: _SalesLinePainter(points: points),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SalesStatusCard extends StatelessWidget {
  const _SalesStatusCard({required this.sales});

  final List<SalesReportRow> sales;

  @override
  Widget build(BuildContext context) {
    final paid = sales.where((sale) => sale.isFullyPaid).length;
    final active = sales.length - paid;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'حالة المبيعات',
            subtitle: 'تقسيم مبسط حسب اكتمال الدفع.',
            icon: Icons.donut_large_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 260,
            child: sales.isEmpty
                ? const AppEmptyState(
                    icon: Icons.donut_large_outlined,
                    title: 'لا توجد مبيعات لعرض الحالة',
                    compact: true,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _SalesDonutPainter(
                            paid: paid,
                            active: active,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${sales.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(
                                  'مبيعات',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LegendRow(
                        label: 'مكتملة',
                        value: '$paid',
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _LegendRow(
                        label: 'نشطة',
                        value: '$active',
                        color: AppColors.chartBlue,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductRankCard extends StatelessWidget {
  const _ProductRankCard({
    required this.rank,
    required this.product,
    required this.maxSales,
  });

  final int rank;
  final TopSellingProduct product;
  final int maxSales;

  @override
  Widget build(BuildContext context) {
    final progress = maxSales == 0 ? 0.0 : product.salesCount / maxSales;

    return AppListCard(
      leading: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
      title: product.productName,
      subtitle: '${product.salesCount} مبيعة',
      tone: rank == 1 ? AppStatusTone.accent : AppStatusTone.neutral,
      trailing: SizedBox(
        width: 88,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            color: rank == 1 ? AppColors.accent : AppColors.primary,
            backgroundColor: AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _ListStack extends StatelessWidget {
  const _ListStack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemCount: children.length,
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
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
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.error_outline,
    title: message,
    compact: true,
  );
}

class _MonthlySalesPoint {
  const _MonthlySalesPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class _MonthKey {
  const _MonthKey(this.year, this.month);

  final int year;
  final int month;

  @override
  bool operator ==(Object other) {
    return other is _MonthKey && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

class _SalesLinePainter extends CustomPainter {
  const _SalesLinePainter({required this.points});

  final List<_MonthlySalesPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    final chartRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 42);
    final maxValue = points.map((point) => point.value).fold<double>(0, math.max);
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final areaPath = Path();
    final linePath = Path();
    final dots = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final x = chartRect.left +
          (points.length == 1 ? 0 : chartRect.width * i / (points.length - 1));
      final y = chartRect.bottom - chartRect.height * (points[i].value / safeMax);
      final point = Offset(x, y);
      dots.add(point);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
        areaPath.moveTo(point.dx, chartRect.bottom);
        areaPath.lineTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
        areaPath.lineTo(point.dx, point.dy);
      }
    }
    areaPath
      ..lineTo(dots.last.dx, chartRect.bottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.chartBlue.withValues(alpha: 0.20),
          AppColors.chartBlue.withValues(alpha: 0.02),
        ],
      ).createShader(chartRect);
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = AppColors.chartBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = AppColors.surfaceCard;
    final dotBorderPaint = Paint()
      ..color = AppColors.chartBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (final dot in dots) {
      canvas.drawCircle(dot, 5.5, dotPaint);
      canvas.drawCircle(dot, 5.5, dotBorderPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final x = chartRect.left +
          (points.length == 1 ? 0 : chartRect.width * i / (points.length - 1));
      textPainter.text = TextSpan(
        text: points[i].label,
        style: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout(minWidth: 42, maxWidth: 42);
      textPainter.paint(canvas, Offset(x - 21, chartRect.bottom + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _SalesLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _SalesDonutPainter extends CustomPainter {
  const _SalesDonutPainter({required this.paid, required this.active});

  final int paid;
  final int active;

  @override
  void paint(Canvas canvas, Size size) {
    final total = paid + active;
    if (total == 0) return;

    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius - 14,
    );
    const strokeWidth = 18.0;
    final basePaint = Paint()
      ..color = AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);

    var startAngle = -math.pi / 2;
    final segments = [
      (value: paid, color: AppColors.success),
      (value: active, color: AppColors.chartBlue),
    ];

    for (final segment in segments) {
      if (segment.value == 0) continue;
      final sweep = math.pi * 2 * segment.value / total;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep - 0.04, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SalesDonutPainter oldDelegate) {
    return oldDelegate.paid != paid || oldDelegate.active != active;
  }
}

String _arabicMonth(int month) {
  const months = [
    'كانون ٢',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين ١',
    'تشرين ٢',
    'كانون ١',
  ];
  return months[month - 1];
}
