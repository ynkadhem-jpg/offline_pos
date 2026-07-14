import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/customer_dao.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('إضافة زبون'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 10),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (_submissionError != null) ...[
                  const SizedBox(height: AppSpacing.fieldGap),
                  Text(
                    _submissionError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
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
              : const Text('إضافة'),
        ),
      ],
    );
  }
}
