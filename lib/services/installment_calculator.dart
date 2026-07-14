class InstallmentCalculation {
  const InstallmentCalculation({
    required this.totalAmount,
    required this.monthlyWithInterest,
    required this.monthlyWithoutInterest,
  });

  final double totalAmount;
  final double monthlyWithInterest;
  final double monthlyWithoutInterest;
}

InstallmentCalculation calculateInstallment({
  required double originalPrice,
  required double interestAmount,
  required int months,
}) {
  if (!originalPrice.isFinite || originalPrice < 0) {
    throw ArgumentError.value(
      originalPrice,
      'originalPrice',
      'Must be a non-negative finite number.',
    );
  }

  if (!interestAmount.isFinite || interestAmount < 0) {
    throw ArgumentError.value(
      interestAmount,
      'interestAmount',
      'Must be a non-negative finite number.',
    );
  }

  if (months <= 0) {
    throw ArgumentError.value(months, 'months', 'Must be greater than zero.');
  }

  final totalAmount = originalPrice + interestAmount;

  return InstallmentCalculation(
    totalAmount: totalAmount,
    monthlyWithInterest: totalAmount / months,
    monthlyWithoutInterest: originalPrice / months,
  );
}
