import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/database.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final AppDatabase _db = AppDatabase();

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  Future<void> _testDatabaseConnection() async {
    try {
      final now = DateTime.now();
      final id = await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              name: 'منتج تجريبي',
              price: 99.0,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final product = await (_db.select(_db.products)
            ..where((row) => row.id.equals(id)))
          .getSingle();

      debugPrint('Task 0.3 DB test — retrieved product: $product');
    } catch (error, stackTrace) {
      debugPrint('Task 0.3 DB test failed: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
      ),
      body: kDebugMode
          ? Center(
              child: FilledButton(
                onPressed: _testDatabaseConnection,
                child: const Text('[DEV] اختبار قاعدة البيانات'),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
