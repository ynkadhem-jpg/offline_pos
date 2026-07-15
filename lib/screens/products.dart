import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/tokens/app_colors.dart';
import '../design_system/tokens/app_radius.dart';
import '../design_system/tokens/app_spacing.dart';
import '../services/database.dart';
import '../services/product_dao.dart';
import 'products/deleted_products_screen.dart';
import 'widgets/app_ui.dart';
import 'widgets/product_form_dialog.dart';

enum ProductSortOption { nameAsc, nameDesc, priceAsc, priceDesc }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    required this.database,
    required this.onDataChanged,
    super.key,
  });

  final AppDatabase database;
  final Future<void> Function() onDataChanged;

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
    _db = widget.database;
    _productDao = ProductDao(_db);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Product>> _productsStream() {
    return _productDao.watchActiveProducts();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchQuery.trim();

    if (query.isEmpty) {
      return products;
    }

    final normalizedQuery = query.toLowerCase();
    return products
        .where(
          (product) => product.name.toLowerCase().contains(normalizedQuery),
        )
        .toList();
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
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ProductFormDialog(productDao: _productDao, product: product),
    );
    if (changed == true) {
      unawaited(widget.onDataChanged());
    }
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
      builder: (dialogContext) =>
          _ProductDeleteDialog(productName: product.name),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              AppPageHeader(
                title: 'المنتجات',
                subtitle: 'تنظيم المنتجات والأسعار مع وصول سريع للأرشيف.',
                action: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showDeletedProducts,
                      icon: const Icon(Icons.restore_from_trash_outlined),
                      label: const Text('المحذوفة'),
                    ),
                    FilledButton.icon(
                      onPressed: _showProductForm,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة منتج'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: _productsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ProductsLoadingState();
                    }

                    if (snapshot.hasError) {
                      return const _ProductsMessage(
                        message: 'حدث خطأ أثناء تحميل المنتجات',
                      );
                    }

                    final allProducts = snapshot.data ?? [];
                    final products = _sortProducts(
                      _filterProducts(allProducts),
                    );
                    return Column(
                      children: [
                        _ProductOverview(
                          totalProducts: allProducts.length,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ProductControls(
                          searchController: _searchController,
                          sortOption: _sortOption,
                          onSearchChanged: _onSearchChanged,
                          onSortChanged: _onSortChanged,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Expanded(
                          child: products.isEmpty
                              ? _ProductsMessage(
                                  message: allProducts.isEmpty
                                      ? 'لا توجد منتجات لعرضها'
                                      : 'لا توجد نتائج مطابقة',
                                  description: allProducts.isEmpty
                                      ? 'أضف المنتجات التي تبيعها حتى تظهر في عمليات التقسيط.'
                                      : 'جرّب تغيير كلمات البحث أو طريقة الترتيب.',
                                  onAddProduct: allProducts.isEmpty
                                      ? _showProductForm
                                      : null,
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 420,
                                    mainAxisExtent: 196,
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                  ),
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    return _ProductCard(
                                      product: product,
                                      onEdit: () => _showProductForm(product),
                                      onDelete: () => _deleteProduct(product),
                                      isDeleting: _deletingProductIds.contains(
                                        product.id,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDeleteDialog extends StatelessWidget {
  const _ProductDeleteDialog({required this.productName});

  final String productName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.rg),
          Expanded(
            child: Text('حذف المنتج؟', style: textTheme.titleLarge),
          ),
        ],
      ),
      content: Text(
        'هل تريد حذف المنتج "$productName"؟ يمكنك استرجاعه لاحقاً من الأرشيف.',
        style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('حذف'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ProductOverview extends StatelessWidget {
  const _ProductOverview({
    required this.totalProducts,
  });

  final int totalProducts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.rg,
          vertical: AppSpacing.sm,
        ),
        backgroundColor: AppColors.surfaceCard.withValues(alpha: 0.72),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'مجموع المنتجات',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$totalProducts',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
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
  });

  final TextEditingController searchController;
  final ProductSortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductSortOption?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final search = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المنتج',
              prefixIcon: Icon(Icons.search),
            ),
          );
          final sort = DropdownButtonFormField<ProductSortOption>(
            initialValue: sortOption,
            isExpanded: true,
            decoration: const InputDecoration(
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
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: AppSpacing.sm),
                sort,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 260, child: sort),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
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
    final price = '${currency.format(product.price)} د.ع';

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.rg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '#${product.id}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: 'نشط',
                icon: Icons.check_circle_outline,
                tone: AppStatusTone.success,
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(AppSpacing.rg),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'السعر',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                child: isDeleting
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.rg),
                        child: CircularProgressIndicator(
                          strokeWidth: AppSpacing.xs,
                        ),
                      )
                    : IconButton.filledTonal(
                        onPressed: onDelete,
                        tooltip: 'حذف المنتج',
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorSoft,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductsLoadingState extends StatelessWidget {
  const _ProductsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppResponsiveWrap(
          wideColumns: 3,
          children: const [
            _SkeletonPanel(height: 126),
            _SkeletonPanel(height: 126),
            _SkeletonPanel(height: 126),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _SkeletonPanel(height: 82),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 196,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const _SkeletonPanel(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final compact = height != null && height! < 120;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: height,
        child: compact
            ? Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 180,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: 160,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: 92,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductsMessage extends StatelessWidget {
  const _ProductsMessage({
    required this.message,
    this.description,
    this.onAddProduct,
  });

  final String message;
  final String? description;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: message,
        description:
            description ?? 'أضف المنتجات التي تبيعها حتى تظهر في عمليات التقسيط.',
        action: onAddProduct == null
            ? null
            : FilledButton.tonalIcon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add),
                label: const Text('إضافة أول منتج'),
              ),
      ),
    );
  }
}
