import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/product_dao.dart';
import 'app_ui.dart';

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

  double? get _previewPrice {
    final normalizedValue = _priceController.text.trim().replaceAll('٫', '.');
    return double.tryParse(normalizedValue);
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

      // ignore: use_build_context_synchronously
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
    final textTheme = Theme.of(context).textTheme;
    final title = widget.isEditing ? 'تعديل المنتج' : 'إضافة منتج';

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
            child: const Icon(
              Icons.inventory_2_outlined,
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
                  'عرّف المنتج وسعره الأساسي لاستخدامه في عمليات التقسيط.',
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
                  validator: _validateName,
                  onChanged: (_) => setState(() => _submissionError = null),
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    hintText: 'مثال: هاتف Samsung A55',
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
                  onChanged: (_) => setState(() => _submissionError = null),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    hintText: 'أدخل السعر بالدينار العراقي',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ProductPricePreview(price: _previewPrice),
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

class _ProductPricePreview extends StatelessWidget {
  const _ProductPricePreview({required this.price});

  final double? price;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('en');
    final textTheme = Theme.of(context).textTheme;
    final isReady = price != null && price!.isFinite && price! > 0;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.72),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isReady ? AppColors.successSoft : AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isReady ? Icons.check_circle_outline : Icons.price_check_outlined,
              color: isReady ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.rg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معاينة السعر',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isReady
                      ? '${currency.format(price)} د.ع'
                      : 'أدخل السعر لعرضه هنا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: isReady ? AppColors.primary : AppColors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
