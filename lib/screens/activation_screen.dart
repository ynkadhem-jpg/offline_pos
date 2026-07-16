import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/activation_validator.dart';
import '../services/license_model.dart';
import '../services/license_service.dart';
import 'main_shell.dart';
import 'widgets/app_ui.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    required this.licenseService,
    this.requiredLicenseType,
    super.key,
  });

  final LicenseService licenseService;
  final LicenseType? requiredLicenseType;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  static const String _activationPhoneNumber = '+9647721064308';

  final TextEditingController _activationCodeController =
      TextEditingController();

  bool _isActivating = false;
  String? _errorText;

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fingerprint = widget.licenseService.deviceFingerprint;
    final canActivate =
        _activationCodeController.text.trim().isNotEmpty && !_isActivating;

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
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: AppColors.accent,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('تفعيل التطبيق', style: textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'انسخ بصمة الجهاز وأرسلها للمطور، ثم أدخل كود التفعيل الذي يصدر لهذا الجهاز فقط.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ActivationContactCard(
                        phoneNumber: _activationPhoneNumber,
                        onCopy: () => _copyPhoneNumber(context),
                        onCall: () => _launchCall(context),
                        onWhatsapp: () => _launchWhatsapp(context),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                      TextField(
                        controller: _activationCodeController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        minLines: 2,
                        maxLines: 4,
                        enabled: !_isActivating,
                        onChanged: (_) {
                          setState(() => _errorText = null);
                        },
                        decoration: InputDecoration(
                          labelText: 'كود التفعيل',
                          hintText: 'TAQ1...',
                          errorText: _errorText,
                          prefixIcon: const Icon(Icons.key_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          FilledButton.icon(
                            onPressed: canActivate ? _activate : null,
                            icon: _isActivating
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Icon(Icons.verified_outlined),
                            label: Text(
                              _isActivating ? 'جاري التفعيل...' : 'تفعيل',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isActivating
                                ? null
                                : () => _copyFingerprint(context, fingerprint),
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

  Future<void> _activate() async {
    final activationCode = _activationCodeController.text;
    if (activationCode.trim().isEmpty) {
      setState(() => _errorText = 'أدخل كود التفعيل أولاً');
      return;
    }

    setState(() {
      _isActivating = true;
      _errorText = null;
    });

    final result = await const ActivationValidator().validate(
      activationCode: activationCode,
      deviceFingerprint: widget.licenseService.deviceFingerprint,
    );

    if (!mounted) return;

    if (!result.isValid) {
      setState(() {
        _isActivating = false;
        _errorText = _messageForFailure(result.failure);
      });
      return;
    }

    final payload = result.payload!;
    if (widget.requiredLicenseType != null &&
        payload.type != widget.requiredLicenseType) {
      setState(() {
        _isActivating = false;
        _errorText = 'بعد انتهاء التجربة يجب إدخال كود تفعيل دائم';
      });
      return;
    }

    await widget.licenseService.storeActivation(
      activationCode: _normalizeActivationCode(activationCode),
      licenseType: payload.type,
      issuedAt: payload.issuedAt,
      expiresAt: payload.expiresAt,
    );

    if (!widget.licenseService.isActivated) {
      if (!mounted) return;
      setState(() {
        _isActivating = false;
        _errorText = 'انتهت صلاحية كود التجربة';
      });
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => const MainShell(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static String _messageForFailure(ActivationValidationFailure? failure) {
    return switch (failure) {
      ActivationValidationFailure.fingerprintMismatch =>
        'هذا الكود لا يخص هذا الجهاز',
      ActivationValidationFailure.invalidSignature => 'كود التفعيل غير صحيح',
      ActivationValidationFailure.unsupportedVersion =>
        'إصدار كود التفعيل غير مدعوم',
      ActivationValidationFailure.unsupportedAlgorithm =>
        'نوع التوقيع غير مدعوم',
      ActivationValidationFailure.wrongApplication =>
        'الكود لا يخص هذا التطبيق',
      ActivationValidationFailure.wrongKey => 'مفتاح التفعيل غير مطابق',
      ActivationValidationFailure.malformed ||
      null => 'صيغة كود التفعيل غير صحيحة',
    };
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

  static String _normalizeActivationCode(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim();
  }

  static Future<void> _copyPhoneNumber(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _activationPhoneNumber));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم نسخ رقم التواصل')));
  }

  Future<void> _launchCall(BuildContext context) async {
    await _launchContactUri(
      context,
      Uri.parse('tel:$_activationPhoneNumber'),
      failureMessage: 'تعذر فتح تطبيق الاتصال',
    );
  }

  Future<void> _launchWhatsapp(BuildContext context) async {
    final fingerprint = widget.licenseService.deviceFingerprint;
    final message =
        'مرحباً، أحتاج تفعيل تطبيق تقسيط.\n'
        'بصمة الجهاز:\n$fingerprint';
    final uri = Uri.https(
      'wa.me',
      '/${_activationPhoneNumber.replaceFirst('+', '')}',
      {'text': message},
    );

    await _launchContactUri(context, uri, failureMessage: 'تعذر فتح واتساب');
  }

  static Future<void> _launchContactUri(
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

    if (launched || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failureMessage)));
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

class _ActivationContactCard extends StatelessWidget {
  const _ActivationContactCard({
    required this.phoneNumber,
    required this.onCopy,
    required this.onCall,
    required this.onWhatsapp,
  });

  final String phoneNumber;
  final VoidCallback onCopy;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  static const Color _whatsappGreen = Color(0xFF25D366);
  static const Color _whatsappSoft = Color(0xFFE7F8EE);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _whatsappSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                    child: _WhatsAppGlyph(size: 26, color: _whatsappGreen),
                  ),
                ),
                const SizedBox(width: AppSpacing.rg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'للحصول على كود التفعيل',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        phoneNumber,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _whatsappGreen,
                    foregroundColor: Colors.white,
                    iconColor: Colors.white,
                  ),
                  onPressed: onWhatsapp,
                  icon: const _WhatsAppGlyph(size: 20, color: Colors.white),
                  label: const Text('واتساب'),
                ),
                OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('اتصال'),
                ),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('نسخ الرقم'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppGlyph extends StatelessWidget {
  const _WhatsAppGlyph({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _WhatsAppGlyphPainter(color)),
    );
  }
}

class _WhatsAppGlyphPainter extends CustomPainter {
  const _WhatsAppGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final stroke = shortest * 0.09;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * 0.52, size.height * 0.47);
    final radius = shortest * 0.35;

    canvas.drawCircle(center, radius, paint);

    final tail = Path()
      ..moveTo(size.width * 0.30, size.height * 0.72)
      ..lineTo(size.width * 0.18, size.height * 0.88)
      ..lineTo(size.width * 0.38, size.height * 0.80);
    canvas.drawPath(tail, paint);

    final phone = Path()
      ..moveTo(size.width * 0.39, size.height * 0.34)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.43,
        size.width * 0.43,
        size.height * 0.62,
        size.width * 0.61,
        size.height * 0.66,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.67,
        size.width * 0.70,
        size.height * 0.59,
        size.width * 0.67,
        size.height * 0.55,
      );
    canvas.drawPath(phone, paint);

    final endpointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.35),
      stroke * 0.78,
      endpointPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.67, size.height * 0.55),
      stroke * 0.78,
      endpointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WhatsAppGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
