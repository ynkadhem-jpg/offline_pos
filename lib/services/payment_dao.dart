import 'package:drift/drift.dart';

import 'database.dart';

class PaymentDao extends DatabaseAccessor<AppDatabase> {
  PaymentDao(super.db);

  Future<int> recordPayment({
    required int installmentId,
    required double amount,
    required DateTime paymentDate,
    String? note,
  }) {
    if (installmentId <= 0) {
      throw ArgumentError.value(
        installmentId,
        'installmentId',
        'Must be greater than zero.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be a positive finite number.',
      );
    }

    return transaction(() async {
      final installmentQuery = select(attachedDatabase.installments)
        ..where((installment) => installment.id.equals(installmentId));
      final installment = await installmentQuery.getSingleOrNull();
      if (installment == null) {
        throw StateError('Installment with ID $installmentId was not found.');
      }
      if (installment.isPaid ||
          installment.totalPaid >= installment.actualDue) {
        throw StateError(
          'Installment with ID $installmentId is already fully paid.',
        );
      }

      final paymentId = await into(attachedDatabase.payments).insert(
        PaymentsCompanion.insert(
          installmentId: installmentId,
          amount: amount,
          paymentDate: paymentDate,
          note: Value(note),
        ),
      );

      final newTotalPaid = installment.totalPaid + amount;
      final affectedRows =
          await (update(
            attachedDatabase.installments,
          )..where((row) => row.id.equals(installmentId))).write(
            InstallmentsCompanion(
              totalPaid: Value(newTotalPaid),
              isPaid: Value(newTotalPaid >= installment.actualDue),
            ),
          );
      if (affectedRows != 1) {
        throw StateError(
          'Installment with ID $installmentId could not be updated.',
        );
      }

      return paymentId;
    });
  }
}
