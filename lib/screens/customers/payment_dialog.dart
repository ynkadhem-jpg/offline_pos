import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/payment_dao.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.installment,
    required this.paymentDao,
    super.key,
  });

  final Installment installment;
  final PaymentDao paymentDao;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _paymentDate;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController()..addListener(_onAmountChanged);
    _noteController = TextEditingController();
    _paymentDate = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount {
    return double.tryParse(
      _amountController.text.trim().replaceAll('٫', '.'),
    );
  }

  String? get _validationError {
    if (_amountController.text.trim().isEmpty) {
      return 'يرجى إدخال مبلغ الدفعة';
    }
    final amount = _amount;
    if (amount == null || !amount.isFinite) {
      return 'مبلغ الدفعة يجب أن يكون رقماً صالحاً';
    }
    if (amount <= 0) {
      return 'مبلغ الدفعة يجب أن يكون أكبر من صفر';
    }
    return null;
  }

  bool get _canSubmit => !_isSubmitting && _validationError == null;

  void _onAmountChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _submissionError = null);
  }

  Future<void> _selectPaymentDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ الدفعة',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (selectedDate == null || !context.mounted) {
      return;
    }
    setState(() {
      _paymentDate = selectedDate;
      _submissionError = null;
    });
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (!_canSubmit || amount == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.paymentDao.recordPayment(
        installmentId: widget.installment.id,
        amount: amount,
        paymentDate: _paymentDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submissionError = error.toString();
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

    return AlertDialog(
      title: const Text('تسجيل دفعة'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.xxl * 10),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _amountController,
                enabled: !_isSubmitting,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'مبلغ الدفعة',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _selectPaymentDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'تاريخ الدفعة: ${_formatDate(_paymentDate)}',
                ),
              ),
              const SizedBox(height: AppSpacing.fieldGap),
              TextField(
                controller: _noteController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.multiline,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
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
