import 'package:drift/drift.dart';

import 'database.dart';

class CustomerDao extends DatabaseAccessor<AppDatabase> {
  CustomerDao(super.db);

  Future<int> addCustomer({
    required String name,
    required String address,
    required String phone,
  }) {
    return into(attachedDatabase.customers).insert(
      CustomersCompanion.insert(
        name: name,
        address: address,
        phone: phone,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<int> updateCustomer({
    required int id,
    required String name,
    required String address,
    required String phone,
  }) {
    return (update(
      attachedDatabase.customers,
    )..where((customer) => customer.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name),
        address: Value(address),
        phone: Value(phone),
      ),
    );
  }

  Future<int> softDeleteCustomer(int id) {
    return (update(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(id)))
        .write(const CustomersCompanion(isDeleted: Value(true)));
  }

  Future<int> restoreCustomer(int id) {
    return (update(attachedDatabase.customers)
          ..where((customer) => customer.id.equals(id)))
        .write(const CustomersCompanion(isDeleted: Value(false)));
  }

  Stream<List<Customer>> watchCustomers() {
    final query = select(attachedDatabase.customers)
      ..where((customer) => customer.isDeleted.equals(false))
      ..orderBy([(customer) => OrderingTerm.asc(customer.name)]);

    return query.watch();
  }

  Stream<int> watchActiveCustomerCount() {
    final countExpression = attachedDatabase.customers.id.count();
    final query = selectOnly(attachedDatabase.customers)
      ..addColumns([countExpression])
      ..where(attachedDatabase.customers.isDeleted.equals(false));

    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  Stream<List<Customer>> watchDeletedCustomers() {
    final query = select(attachedDatabase.customers)
      ..where((customer) => customer.isDeleted.equals(true))
      ..orderBy([(customer) => OrderingTerm.asc(customer.name)]);

    return query.watch();
  }

  Stream<List<Customer>> searchCustomers(String searchTerm) {
    final trimmedSearchTerm = searchTerm.trim();
    final query = select(attachedDatabase.customers)
      ..where(
        (customer) =>
            customer.isDeleted.equals(false) &
            customer.name.like('%$trimmedSearchTerm%'),
      )
      ..orderBy([(customer) => OrderingTerm.asc(customer.name)]);

    return query.watch();
  }
}
