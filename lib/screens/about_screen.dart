import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import 'widgets/app_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _phoneNumber = '+9647721064308';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: 'عن التطبيق',
                subtitle: 'معلومات تطبيق تقسيط وطرق التواصل مع المطور.',
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPanel(
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/branding/app_logo.png',
                                fit: BoxFit.cover,
                                semanticLabel: 'شعار تطبيق تقسيط',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text('تقسيط', style: textTheme.headlineSmall),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'إدارة المبيعات والأقساط والدفعات بسهولة وأمان.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'جميع الحقوق محفوظة © 2026',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'تطوير Yousef N Kadhem — Mars Team',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppSectionHeader(
                              title: 'التواصل مع المطور',
                              subtitle:
                                  'للدعم الفني أو الاستفسار عن تفعيل التطبيق.',
                              icon: Icons.support_agent_outlined,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.whatsappSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.whatsapp.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: AppSpacing.minTouchTarget,
                                    height: AppSpacing.minTouchTarget,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCard,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.whatsapp,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'واتساب واتصال',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        const Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: SelectableText(
                                            _phoneNumber,
                                            style: TextStyle(
                                              color: AppColors.inkMuted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.whatsapp,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _openWhatsApp(context),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                  ),
                                  label: const Text('واتساب'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _call(context),
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('اتصال'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _copyNumber(context),
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('نسخ الرقم'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _copyNumber(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _phoneNumber));
    if (!context.mounted) return;
    _showMessage(context, 'تم نسخ رقم التواصل');
  }

  static Future<void> _call(BuildContext context) {
    return _launch(
      context,
      Uri(scheme: 'tel', path: _phoneNumber),
      failureMessage: 'تعذر فتح تطبيق الاتصال',
    );
  }

  static Future<void> _openWhatsApp(BuildContext context) {
    final uri = Uri.https('wa.me', '/${_phoneNumber.replaceFirst('+', '')}', {
      'text': 'مرحباً، أحتاج المساعدة بخصوص تطبيق تقسيط.',
    });
    return _launch(context, uri, failureMessage: 'تعذر فتح واتساب');
  }

  static Future<void> _launch(
    BuildContext context,
    Uri uri, {
    required String failureMessage,
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      launched = false;
    }
    if (!launched && context.mounted) {
      _showMessage(context, failureMessage);
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
