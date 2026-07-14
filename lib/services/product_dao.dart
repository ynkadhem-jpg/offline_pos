import 'package:drift/drift.dart';

import 'database.dart';

class ProductDao extends DatabaseAccessor<AppDatabase> {
  ProductDao(super.db);

  Future<int> addProduct({
    required String name,
    required double price,
  }) {
    final now = DateTime.now();

    return into(attachedDatabase.products).insert(
      ProductsCompanion.insert(
        name: name,
        price: price,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> updateProduct({
    required int id,
    required String name,
    required double price,
  }) {
    return (update(attachedDatabase.products)
          ..where((product) => product.id.equals(id)))
        .write(
      ProductsCompanion(
        name: Value(name),
        price: Value(price),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> softDeleteProduct(int id) {
    return (update(attachedDatabase.products)
          ..where((product) => product.id.equals(id)))
        .write(
      ProductsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreProduct(int id) {
    return (update(attachedDatabase.products)
          ..where((product) => product.id.equals(id)))
        .write(
      ProductsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<Product>> watchActiveProducts() {
    final query = select(attachedDatabase.products)
      ..where((product) => product.isDeleted.equals(false))
      ..orderBy([(product) => OrderingTerm.asc(product.name)]);

    return query.watch();
  }

  Future<List<Product>> getDeletedProducts() {
    final query = select(attachedDatabase.products)
      ..where((product) => product.isDeleted.equals(true))
      ..orderBy([(product) => OrderingTerm.asc(product.name)]);

    return query.get();
  }

  Stream<List<Product>> searchProductsByName(String query) {
  final trimmed = query.trim();

  final productsQuery = select(attachedDatabase.products)
    ..where(
      (product) =>
          product.isDeleted.equals(false) &
          product.name.like('%$trimmed%'),
    )
    ..orderBy([(product) => OrderingTerm.asc(product.name)]);

  return productsQuery.watch();
}
   
}
