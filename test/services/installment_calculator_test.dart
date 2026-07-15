import 'package:flutter_test/flutter_test.dart';
import 'package:taqseet/services/installment_calculator.dart';

void main() {
  group('calculateInstallment', () {
    test('calculates installments with a fixed interest amount', () {
      // Arrange
      const originalPrice = 1000.0;
      const interestAmount = 200.0;
      const months = 4;

      // Act
      final result = calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: interestAmount,
        months: months,
      );

      // Assert
      expect(result.totalAmount, 1200.0);
      expect(result.monthlyWithInterest, 300.0);
      expect(result.monthlyWithoutInterest, 250.0);
    });

    test('calculates installments with zero interest', () {
      // Arrange
      const originalPrice = 900.0;
      const interestAmount = 0.0;
      const months = 3;

      // Act
      final result = calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: interestAmount,
        months: months,
      );

      // Assert
      expect(result.totalAmount, 900.0);
      expect(result.monthlyWithInterest, 300.0);
      expect(result.monthlyWithoutInterest, 300.0);
    });

    test('calculates a one-month installment', () {
      // Arrange
      const originalPrice = 750.0;
      const interestAmount = 150.0;
      const months = 1;

      // Act
      final result = calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: interestAmount,
        months: months,
      );

      // Assert
      expect(result.totalAmount, 900.0);
      expect(result.monthlyWithInterest, 900.0);
      expect(result.monthlyWithoutInterest, 750.0);
    });

    test('keeps fractional monthly results unrounded', () {
      // Arrange
      const originalPrice = 1000.0;
      const interestAmount = 100.0;
      const months = 3;

      // Act
      final result = calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: interestAmount,
        months: months,
      );

      // Assert
      expect(result.totalAmount, 1100.0);
      expect(result.monthlyWithInterest, closeTo(366.6666666666667, 1e-10));
      expect(result.monthlyWithoutInterest, closeTo(333.3333333333333, 1e-10));
    });

    test('rejects zero months', () {
      // Arrange
      const months = 0;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: 1000,
        interestAmount: 200,
        months: months,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects negative months', () {
      // Arrange
      const months = -1;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: 1000,
        interestAmount: 200,
        months: months,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects a negative original price', () {
      // Arrange
      const originalPrice = -1.0;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: 200,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects a negative interest amount', () {
      // Arrange
      const interestAmount = -1.0;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: 1000,
        interestAmount: interestAmount,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects a NaN original price', () {
      // Arrange
      const originalPrice = double.nan;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: 200,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects a NaN interest amount', () {
      // Arrange
      const interestAmount = double.nan;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: 1000,
        interestAmount: interestAmount,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects an infinite original price', () {
      // Arrange
      const originalPrice = double.infinity;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: originalPrice,
        interestAmount: 200,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });

    test('rejects an infinite interest amount', () {
      // Arrange
      const interestAmount = double.infinity;

      // Act
      Object? act() => calculateInstallment(
        originalPrice: 1000,
        interestAmount: interestAmount,
        months: 4,
      );

      // Assert
      expect(act, throwsArgumentError);
    });
  });
}
