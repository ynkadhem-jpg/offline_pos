import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_spacing.dart';
import '../services/database.dart';
import '../services/product_dao.dart';
import 'products/deleted_products_screen.dart';
import 'widgets/product_form_dialog.dart';

enum ProductSortOption { nameAsc, nameDesc, priceAsc, priceDesc }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final AppDatabase _db;
  late final ProductDao _productDao;
  late final TextEditingController _searchController;

  String _searchQuery = '';
  ProductSortOption _sortOption = ProductSortOption.nameAsc;
  final Set<int> _deletingProductIds = {};

  @override
  void initState() {
    super.initState();
    _db = AppDatabase();
    _productDao = ProductDao(_db);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _db.close();
    super.dispose();
  }

  Stream<List<Product>> _productsStream() {
    final query = _searchQuery.trim();

    if (query.isEmpty) {
      return _productDao.watchActiveProducts();
    }

    return _productDao.searchProductsByName(query);
  }

  List<Product> _sortProducts(List<Product> products) {
    final sortedProducts = [...products];

    switch (_sortOption) {
      case ProductSortOption.nameAsc:
        sortedProducts.sort((a, b) => a.name.compareTo(b.name));
      case ProductSortOption.nameDesc:
        sortedProducts.sort((a, b) => b.name.compareTo(a.name));
      case ProductSortOption.priceAsc:
        sortedProducts.sort((a, b) => a.price.compareTo(b.price));
      case ProductSortOption.priceDesc:
        sortedProducts.sort((a, b) => b.price.compareTo(a.price));
    }

    return sortedProducts;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _onSortChanged(ProductSortOption? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _sortOption = value;
    });
  }

  Future<void> _showProductForm([Product? product]) async {
    await showDialog<bool>(
      context: context,
      builder: (context) =>
          ProductFormDialog(productDao: _productDao, product: product),
    );
  }

  Future<void> _showDeletedProducts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DeletedProductsScreen(productDao: _productDao),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    if (_deletingProductIds.contains(product.id)) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المنتج؟'),
        content: Text(
          'هل تريد حذف المنتج "${product.name}"؟ يمكنك استرجاعه لاحقاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    setState(() {
      _deletingProductIds.add(product.id);
    });

    try {
      final affectedRows = await _productDao.softDeleteProduct(product.id);
      if (affectedRows != 1) {
        throw StateError('Product was not soft-deleted.');
      }

      if (!context.mounted) {
        return;
      }

      setState(() {
        _deletingProductIds.remove(product.id);
      });
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      setState(() {
        _deletingProductIds.remove(product.id);
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حذف المنتج. يرجى المحاولة مرة أخرى'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            onPressed: _showDeletedProducts,
            tooltip: 'المنتجات المحذوفة',
            icon: const Icon(Icons.restore_from_trash_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            _ProductControls(
              searchController: _searchController,
              sortOption: _sortOption,
              onSearchChanged: _onSearchChanged,
              onSortChanged: _onSortChanged,
              onAddProduct: _showProductForm,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _productsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const _ProductsMessage(
                      message: 'حدث خطأ أثناء تحميل المنتجات',
                    );
                  }

                  final products = _sortProducts(snapshot.data ?? []);

                  if (products.isEmpty) {
                    return const _ProductsMessage(
                      message: 'لا توجد منتجات لعرضها',
                    );
                  }

                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _ProductListItem(
                        product: products[index],
                        onEdit: () => _showProductForm(products[index]),
                        onDelete: () => _deleteProduct(products[index]),
                        isDeleting: _deletingProductIds.contains(
                          products[index].id,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductControls extends StatelessWidget {
  const _ProductControls({
    required this.searchController,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onAddProduct,
  });

  final TextEditingController searchController;
  final ProductSortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductSortOption?> onSortChanged;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'بحث',
              hintText: 'ابحث باسم المنتج',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: AppSpacing.xxl * 5,
          child: DropdownButtonFormField<ProductSortOption>(
            initialValue: sortOption,
            decoration: const InputDecoration(
              labelText: 'الترتيب',
              prefixIcon: Icon(Icons.sort),
            ),
            items: const [
              DropdownMenuItem(
                value: ProductSortOption.nameAsc,
                child: Text('الاسم تصاعدي'),
              ),
              DropdownMenuItem(
                value: ProductSortOption.nameDesc,
                child: Text('الاسم تنازلي'),
              ),
              DropdownMenuItem(
                value: ProductSortOption.priceAsc,
                child: Text('السعر تصاعدي'),
              ),
              DropdownMenuItem(
                value: ProductSortOption.priceDesc,
                child: Text('السعر تنازلي'),
              ),
            ],
            onChanged: onSortChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton.icon(
          onPressed: onAddProduct,
          icon: const Icon(Icons.add),
          label: const Text('إضافة منتج'),
        ),
      ],
    );
  }
}

class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.decimalPattern('en');
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
              '${currency.format(product.price)} د.ع',
              style: textTheme.titleMedium,
            ),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              onPressed: isDeleting ? null : onEdit,
              tooltip: 'تعديل المنتج',
              icon: const Icon(Icons.edit_outlined),
            ),
            if (isDeleting)
              const SizedBox.square(
                dimension: AppSpacing.minTouchTarget,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
                ),
              )
            else
              IconButton(
                onPressed: onDelete,
                tooltip: 'حذف المنتج',
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductsMessage extends StatelessWidget {
  const _ProductsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
