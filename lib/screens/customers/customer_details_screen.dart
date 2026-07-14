import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';

class CustomerDetailsScreen extends StatelessWidget {
  const CustomerDetailsScreen({required this.customer, super.key});

  final Customer customer;

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
                Text('المنتجات المأخوذة', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'لا توجد منتجات مضافة لهذا الزبون حالياً',
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
