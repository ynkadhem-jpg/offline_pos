import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/installment_calculator.dart';
import '../../services/product_dao.dart';
import '../../services/sale_dao.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({
    required this.customerId,
    required this.productDao,
    required this.saleDao,
    super.key,
  });

  final int customerId;
  final ProductDao productDao;
  final SaleDao saleDao;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  late final Stream<List<Product>> _productsStream;
  late final TextEditingController _priceController;
  late final TextEditingController _interestController;
  late final TextEditingController _monthsController;

  int? _selectedProductId;
  late DateTime _startDate;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _productsStream = widget.productDao.watchActiveProducts();
    _priceController = TextEditingController()..addListener(_refreshPreview);
    _interestController = TextEditingController(text: '0')
      ..addListener(_refreshPreview);
    _monthsController = TextEditingController()..addListener(_refreshPreview);
    _startDate = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _priceController
      ..removeListener(_refreshPreview)
      ..dispose();
    _interestController
      ..removeListener(_refreshPreview)
      ..dispose();
    _monthsController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {
        _submissionError = null;
      });
    }
  }

  double? _parseDecimal(String value) {
    return double.tryParse(value.trim().replaceAll('٫', '.'));
  }

  int? _parseMonths(String value) => int.tryParse(value.trim());

  InstallmentCalculation? get _calculation {
    final price = _parseDecimal(_priceController.text);
    final interest = _parseDecimal(_interestController.text);
    final months = _parseMonths(_monthsController.text);
    if (_selectedProductId == null ||
        price == null ||
        interest == null ||
        months == null) {
      return null;
    }

    try {
      return calculateInstallment(
        originalPrice: price,
        interestAmount: interest,
        months: months,
      );
    } on ArgumentError {
      return null;
    }
  }

  String? get _validationError {
    if (_selectedProductId == null) {
      return 'يرجى اختيار المنتج';
    }
    if (_priceController.text.trim().isEmpty) {
      return 'يرجى إدخال السعر الأصلي';
    }
    if (_interestController.text.trim().isEmpty) {
      return 'يرجى إدخال مبلغ الفائدة';
    }
    if (_monthsController.text.trim().isEmpty) {
      return 'يرجى إدخال عدد الأشهر';
    }

    final price = _parseDecimal(_priceController.text);
    final interest = _parseDecimal(_interestController.text);
    final months = _parseMonths(_monthsController.text);
    if (price == null) {
      return 'السعر الأصلي يجب أن يكون رقماً صالحاً';
    }
    if (interest == null) {
      return 'مبلغ الفائدة يجب أن يكون رقماً صالحاً';
    }
    if (months == null) {
      return 'عدد الأشهر يجب أن يكون عدداً صحيحاً';
    }

    try {
      calculateInstallment(
        originalPrice: price,
        interestAmount: interest,
        months: months,
      );
      return null;
    } on ArgumentError catch (error) {
      if (error.name == 'originalPrice') {
        return 'السعر الأصلي يجب أن يكون صفراً أو رقماً موجباً';
      }
      if (error.name == 'interestAmount') {
        return 'مبلغ الفائدة يجب أن يكون صفراً أو رقماً موجباً';
      }
      if (error.name == 'months') {
        return 'عدد الأشهر يجب أن يكون أكبر من صفر';
      }
      return 'القيم المدخلة غير صالحة';
    }
  }

  bool get _canSubmit => !_isSubmitting && _calculation != null;

  void _selectProduct(int? productId, List<Product> products) {
    if (productId == null || _isSubmitting) {
      return;
    }
    final product = products.firstWhere((item) => item.id == productId);
    setState(() {
      _selectedProductId = productId;
      _submissionError = null;
    });
    _priceController.text = product.price.toString();
  }

  Future<void> _selectStartDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ البدء',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (selectedDate == null || !context.mounted) {
      return;
    }
    setState(() => _startDate = selectedDate);
  }

  Future<void> _submit() async {
    final calculation = _calculation;
    final productId = _selectedProductId;
    if (_isSubmitting || calculation == null || productId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.saleDao.createSale(
        customerId: widget.customerId,
        productId: productId,
        originalPrice: _parseDecimal(_priceController.text)!,
        interestAmount: _parseDecimal(_interestController.text)!,
        months: _parseMonths(_monthsController.text)!,
        startDate: _startDate,
      );
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submissionError =
            'تعذر إنشاء عملية البيع. يرجى التحقق من البيانات والمحاولة مرة أخرى';
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final calculation = _calculation;

    return AlertDialog(
      title: const Text('إضافة منتج'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 10),
        child: SingleChildScrollView(
          child: StreamBuilder<List<Product>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'تعذر تحميل المنتجات',
                  style: TextStyle(color: colorScheme.error),
                );
              }

              final products = snapshot.data ?? [];
              final currency = NumberFormat.decimalPattern('en');
              if (products.isEmpty) {
                return const Text(
                  'لا توجد منتجات متاحة. أضف منتجاً من شاشة المنتجات أولاً',
                  textAlign: TextAlign.center,
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: products.any(
                      (product) => product.id == _selectedProductId,
                    )
                        ? _selectedProductId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'المنتج',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      for (final product in products)
                        DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.name} — '
                            '${currency.format(product.price)} د.ع',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) => _selectProduct(value, products),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                  TextField(
                    controller: _priceController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'السعر الأصلي',
                      prefixIcon: Icon(Icons.price_change_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                  TextField(
                    controller: _interestController,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ الفائدة الثابتة',
                      prefixIcon: Icon(Icons.add_chart_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                  TextField(
                    controller: _monthsController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'عدد الأشهر',
                      prefixIcon: Icon(Icons.calendar_view_month_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _selectStartDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('تاريخ البدء: ${_formatDate(_startDate)}'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CalculationPreview(
                    calculation: calculation,
                    originalPrice: _parseDecimal(_priceController.text),
                    interestAmount: _parseDecimal(_interestController.text),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _validationError!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  if (_submissionError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _submissionError!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

class _CalculationPreview extends StatelessWidget {
  const _CalculationPreview({
    required this.calculation,
    required this.originalPrice,
    required this.interestAmount,
  });

  final InstallmentCalculation? calculation;
  final double? originalPrice;
  final double? interestAmount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            _PreviewValue(
              label: 'المبلغ الكلي',
              value: calculation?.totalAmount,
            ),
            _PreviewValue(
              label: 'القسط الشهري',
              value: calculation?.monthlyWithInterest,
            ),
            _PreviewValue(label: 'السعر الأصلي', value: originalPrice),
            _PreviewValue(label: 'الفائدة', value: interestAmount),
            if (calculation == null)
              Text('أكمل البيانات لعرض الحساب', style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _PreviewValue extends StatelessWidget {
  const _PreviewValue({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.decimalPattern('en');

    return SizedBox(
      width: AppSpacing.xxl * 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value == null ? '—' : '${currency.format(value)} د.ع',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
