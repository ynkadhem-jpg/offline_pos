import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../services/customer_dao.dart';
import '../../services/database.dart';
import '../widgets/app_ui.dart';

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({
    required this.customerDao,
    this.customer,
    super.key,
  });

  final CustomerDao customerDao;
  final Customer? customer;

  bool get isEditing => customer != null;

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
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
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
      final customer = widget.customer;
      if (customer == null) {
        await widget.customerDao.addCustomer(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      } else {
        await widget.customerDao.updateCustomer(
          id: customer.id,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      }

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
    final title = widget.isEditing ? 'تعديل بيانات الزبون' : 'إضافة زبون';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              widget.isEditing
                  ? Icons.manage_accounts_outlined
                  : Icons.person_add_alt_1,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.rg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'الاسم والعنوان ورقم الهاتف.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 10),
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
                  validator: (value) =>
                      _validateRequired(value, 'يرجى إدخال اسم الزبون'),
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
                  validator: (value) =>
                      _validateRequired(value, 'يرجى إدخال العنوان'),
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
                )
              : Text(widget.isEditing ? 'حفظ' : 'إضافة'),
        ),
      ],
    );
  }
}
