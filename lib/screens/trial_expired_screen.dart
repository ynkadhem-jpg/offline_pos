import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/license_model.dart';
import '../services/license_service.dart';
import 'activation_screen.dart';
import 'widgets/app_ui.dart';

class TrialExpiredScreen extends StatelessWidget {
  const TrialExpiredScreen({required this.licenseService, super.key});

  final LicenseService licenseService;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expiresAt = licenseService.expiresAt;
    final remainingDays = licenseService.remainingTrialDays ?? 0;
    final fingerprint = licenseService.deviceFingerprint;

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: AppPanel(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: const Icon(
                            Icons.timer_off_outlined,
                            color: AppColors.error,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'انتهت الفترة التجريبية',
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'انتهت مدة التجربة لهذا الجهاز. للاستمرار باستخدام التطبيق، يجب إدخال كود تفعيل دائم.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppResponsiveWrap(
                        wideColumns: 2,
                        mediumColumns: 2,
                        children: [
                          _TrialInfoTile(
                            icon: Icons.event_busy_outlined,
                            label: 'تاريخ الانتهاء',
                            value: expiresAt == null
                                ? 'غير متوفر'
                                : _formatDateTime(expiresAt),
                          ),
                          _TrialInfoTile(
                            icon: Icons.hourglass_empty_outlined,
                            label: 'الأيام المتبقية',
                            value: '$remainingDays يوم',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'بصمة الجهاز',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: SelectableText(
                            _formatFingerprint(fingerprint),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => ActivationScreen(
                                    licenseService: licenseService,
                                    requiredLicenseType: LicenseType.lifetime,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('إدخال كود دائم'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _copyFingerprint(context, fingerprint),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('نسخ البصمة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatFingerprint(String fingerprint) {
    final buffer = StringBuffer();
    for (var index = 0; index < fingerprint.length; index += 4) {
      if (index > 0) buffer.write(' ');
      final end = index + 4 > fingerprint.length
          ? fingerprint.length
          : index + 4;
      buffer.write(fingerprint.substring(index, end));
    }
    return buffer.toString();
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  static Future<void> _copyFingerprint(
    BuildContext context,
    String fingerprint,
  ) async {
    await Clipboard.setData(ClipboardData(text: fingerprint));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم نسخ بصمة الجهاز')));
  }
}

class _TrialInfoTile extends StatelessWidget {
  const _TrialInfoTile({
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.rg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: textTheme.titleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
