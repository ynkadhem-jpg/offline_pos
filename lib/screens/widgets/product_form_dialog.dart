import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/product_dao.dart';

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({required this.productDao, this.product, super.key});

  final ProductDao productDao;
  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال اسم المنتج';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال السعر';
    }

    final normalizedValue = value.trim().replaceAll('٫', '.');
    final price = double.tryParse(normalizedValue);

    if (price == null || !price.isFinite || price <= 0) {
      return 'يرجى إدخال سعر أكبر من صفر';
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

    final name = _nameController.text.trim();
    final price = double.parse(
      _priceController.text.trim().replaceAll('٫', '.'),
    );

    try {
      final product = widget.product;

      if (product == null) {
        await widget.productDao.addProduct(name: name, price: price);
      } else {
        await widget.productDao.updateProduct(
          id: product.id,
          name: name,
          price: price,
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
        _submissionError = 'تعذر حفظ المنتج. يرجى المحاولة مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.isEditing ? 'تعديل المنتج' : 'إضافة منتج'),
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
                  validator: _validateName,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                TextFormField(
                  controller: _priceController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: _validatePrice,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    prefixIcon: Icon(Icons.payments_outlined),
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
              : Text(widget.isEditing ? 'حفظ' : 'إضافة'),
        ),
      ],
    );
  }
}
