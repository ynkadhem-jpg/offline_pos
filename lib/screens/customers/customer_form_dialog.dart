import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../services/customer_dao.dart';
import '../widgets/app_ui.dart';

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({required this.customerDao, super.key});

  final CustomerDao customerDao;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;

  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _validateRequired(value, 'يرجى إدخال رقم الهاتف');
    if (requiredError != null) {
      return requiredError;
    }

    final validPhoneCharacters = RegExp(r'^[0-9٠-٩۰-۹+()\-\s]+$');
    if (!validPhoneCharacters.hasMatch(value!.trim())) {
      return 'رقم الهاتف يحتوي على رموز غير صالحة';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.customerDao.addCustomer(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submissionError = 'تعذر حفظ الزبون. يرجى المحاولة مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AppPanel(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [AppColors.primary, AppColors.primaryHover],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إضافة زبون جديد',
                                style: textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'أدخل معلومات الزبون الأساسية لبدء البيع بالتقسيط.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.74),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isSubmitting,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              validator: (value) => _validateRequired(
                                value,
                                'يرجى إدخال اسم الزبون',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'اسم الزبون',
                                hintText: 'مثال: أحمد علي',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.fieldGap),
                            TextFormField(
                              controller: _addressController,
                              enabled: !_isSubmitting,
                              textInputAction: TextInputAction.next,
                              validator: (value) => _validateRequired(
                                value,
                                'يرجى إدخال العنوان',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'العنوان',
                                hintText: 'المنطقة أو أقرب نقطة دالة',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.fieldGap),
                            TextFormField(
                              controller: _phoneController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              validator: _validatePhone,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف',
                                hintText: '07xxxxxxxxx',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            if (_submissionError != null) ...[
                              const SizedBox(height: AppSpacing.fieldGap),
                              AppStatusChip(
                                label: _submissionError!,
                                tone: AppStatusTone.error,
                                icon: Icons.error_outline,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    child: const Text('إلغاء'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        _isSubmitting ? null : _submit,
                                    icon: _isSubmitting
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check),
                                    label: Text(
                                      _isSubmitting ? 'جاري الحفظ' : 'إضافة',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
