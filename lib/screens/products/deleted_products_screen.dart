import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../services/database.dart';
import '../../services/product_dao.dart';

class DeletedProductsScreen extends StatefulWidget {
  const DeletedProductsScreen({required this.productDao, super.key});

  final ProductDao productDao;

  @override
  State<DeletedProductsScreen> createState() => _DeletedProductsScreenState();
}

class _DeletedProductsScreenState extends State<DeletedProductsScreen> {
  late Future<List<Product>> _deletedProductsFuture;
  final Set<int> _restoringProductIds = {};

  @override
  void initState() {
    super.initState();
    _deletedProductsFuture = widget.productDao.getDeletedProducts();
  }

  void _reloadDeletedProducts() {
    setState(() {
      _deletedProductsFuture = widget.productDao.getDeletedProducts();
    });
  }

  Future<void> _restoreProduct(Product product) async {
    if (_restoringProductIds.contains(product.id)) {
      return;
    }

    setState(() {
      _restoringProductIds.add(product.id);
    });

    try {
      final affectedRows = await widget.productDao.restoreProduct(product.id);
      if (affectedRows != 1) {
        throw StateError('Product was not restored.');
      }

      if (!context.mounted) {
        return;
      }

      setState(() {
        _restoringProductIds.remove(product.id);
        _deletedProductsFuture = widget.productDao.getDeletedProducts();
      });
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      setState(() {
        _restoringProductIds.remove(product.id);
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر استرجاع المنتج. يرجى المحاولة مرة أخرى'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات المحذوفة')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: FutureBuilder<List<Product>>(
          future: _deletedProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DeletedProductsMessage(
                message: 'حدث خطأ أثناء تحميل المنتجات المحذوفة',
                actionLabel: 'إعادة المحاولة',
                onAction: _reloadDeletedProducts,
              );
            }

            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const _DeletedProductsMessage(
                message: 'لا توجد منتجات محذوفة',
              );
            }

            return ListView.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final product = products[index];
                return _DeletedProductListItem(
                  product: product,
                  isRestoring: _restoringProductIds.contains(product.id),
                  onRestore: () => _restoreProduct(product),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DeletedProductListItem extends StatelessWidget {
  const _DeletedProductListItem({
    required this.product,
    required this.isRestoring,
    required this.onRestore,
  });

  final Product product;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.xxl + AppSpacing.xl,
              child: Text('#${product.id}', style: textTheme.labelLarge),
            ),
            Expanded(child: Text(product.name, style: textTheme.titleMedium)),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${product.price.toStringAsFixed(2)} د.ع',
              style: textTheme.titleMedium,
            ),
            const SizedBox(width: AppSpacing.md),
            if (isRestoring)
              const SizedBox.square(
                dimension: AppSpacing.minTouchTarget,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
                ),
              )
            else
              IconButton(
                onPressed: onRestore,
                tooltip: 'استرجاع المنتج',
                icon: const Icon(Icons.restore),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeletedProductsMessage extends StatelessWidget {
  const _DeletedProductsMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
