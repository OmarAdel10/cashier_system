import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_state.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';

class ProductCategoryGrid extends StatefulWidget {
  const ProductCategoryGrid({
    super.key,
    required this.businessType,
    required this.onProductTap,
    required this.gridFocus,
  });

  final BusinessType businessType;
  final ValueChanged<ProductEntity> onProductTap;
  final FocusNode gridFocus;

  @override
  State<ProductCategoryGrid> createState() => ProductCategoryGridState();
}

class ProductCategoryGridState extends State<ProductCategoryGrid> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _search = ValueNotifier('');
  final ValueNotifier<String?> _selectedCategory = ValueNotifier(null);
  final ValueNotifier<List<String>> _favoriteBarcodes = ValueNotifier(const []);
  final Map<String, FocusNode> _favoriteNodes = <String, FocusNode>{};

  List<String> get favoriteBarcodes => _favoriteBarcodes.value;

  void focusIndexForAlt(FocusNode fallback, int slotIndex) {
    final barcodes = _favoriteBarcodes.value;
    if (slotIndex < 0 || slotIndex >= barcodes.length) {
      fallback.requestFocus();
      return;
    }
    (_favoriteNodes[barcodes[slotIndex]] ?? fallback).requestFocus();
  }

  void _syncFavoriteNodes(List<ProductEntity> favorites) {
    final kept = <String>{};
    for (final product in favorites) {
      kept.add(product.barcode);
      _favoriteNodes.putIfAbsent(product.barcode, FocusNode.new);
    }
    final stale = _favoriteNodes.keys.where((b) => !kept.contains(b)).toList();
    for (final barcode in stale) {
      _favoriteNodes.remove(barcode)?.dispose();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _search.dispose();
    _selectedCategory.dispose();
    _favoriteBarcodes.dispose();
    for (final node in _favoriteNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    final favoritesEnabled =
        widget.businessType.favoritesEnabled &&
        context.select<SettingsBloc, bool>(
          (s) => s.state.settings.favoritesStripEnabled,
        );

    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final allProducts = state.inventoryMap.values.toList();
        final favorites = favoritesEnabled
            ? state.quickTileList
            : const <ProductEntity>[];
        _favoriteBarcodes.value = favorites.map((p) => p.barcode).toList();
        _syncFavoriteNodes(favorites);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.sm,
                Spacing.sm,
                0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    _search.value = value.toLowerCase().trim(),
                decoration: InputDecoration(
                  hintText: t.translate(
                    'search.cafe.hint',
                    languageCode: langCode,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            if (favorites.isNotEmpty)
              _FavoritesStrip(
                key: const ValueKey('favorites-strip'),
                favorites: favorites,
                onProductTap: widget.onProductTap,
                langCode: langCode,
                nodeFor: (barcode) => _favoriteNodes[barcode],
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 800;
                  return _buildNavArea(
                    context,
                    allProducts: allProducts,
                    wide: wide,
                    langCode: langCode,
                    t: t,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavArea(
    BuildContext context, {
    required List<ProductEntity> allProducts,
    required bool wide,
    required String langCode,
    required LocalizationService t,
  }) {
    final categories = widget.businessType.hasCategories
        ? BusinessTypeRegistry.defaultCategories[widget.businessType] ??
              const <String>[]
        : const <String>[];
    final filtered = AnimatedBuilder(
      animation: Listenable.merge([_search, _selectedCategory]),
      builder: (context, _) {
        final query = _search.value;
        final selected = _selectedCategory.value;
        final products = allProducts.where((p) {
          if (selected != null && p.category != selected) return false;
          if (query.isNotEmpty && !(p.name.toLowerCase().contains(query))) {
            return false;
          }
          return true;
        }).toList();
        return _ProductGrid(
          products: products,
          onProductTap: widget.onProductTap,
          langCode: langCode,
          gridFocus: widget.gridFocus,
        );
      },
    );

    if (!widget.businessType.hasCategories) {
      return filtered;
    }

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryRail(
            key: const ValueKey('product-grid.rail'),
            categories: categories,
            selected: _selectedCategory,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: filtered),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryChipRow(
          key: const ValueKey('product-grid.chip-row'),
          categories: categories,
          selected: _selectedCategory,
        ),
        Expanded(child: filtered),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    super.key,
    required this.categories,
    required this.selected,
  });

  final List<String> categories;
  final ValueNotifier<String?> selected;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    return SizedBox(
      width: 140,
      child: ValueListenableBuilder<String?>(
        valueListenable: selected,
        builder: (context, current, _) {
          return ListView(
            padding: const EdgeInsets.all(Spacing.sm),
            children: [
              _chip(
                label: t.translate(
                  'checkout.category.all',
                  languageCode: langCode,
                ),
                selectedValue: null,
                current: current,
              ),
              for (final category in categories)
                _chip(
                  label: category,
                  selectedValue: category,
                  current: current,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required String? selectedValue,
    required String? current,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ChoiceChip(
        label: Text(label),
        selected: current == selectedValue,
        onSelected: (_) => selected.value = selectedValue,
      ),
    );
  }
}

class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({
    super.key,
    required this.categories,
    required this.selected,
  });

  final List<String> categories;
  final ValueNotifier<String?> selected;

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(Spacing.sm),
        child: Row(
          children: [
            ChoiceChip(
              label: Text(
                t.translate('checkout.category.all', languageCode: langCode),
              ),
              selected: selected.value == null,
              onSelected: (_) => selected.value = null,
            ),
            for (final category in categories) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(category),
                selected: selected.value == category,
                onSelected: (_) => selected.value = category,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.onProductTap,
    required this.langCode,
    required this.gridFocus,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity> onProductTap;
  final String langCode;
  final FocusNode gridFocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: gridFocus,
      child: GridView.builder(
        padding: const EdgeInsets.all(Spacing.sm),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisExtent: 120,
          crossAxisSpacing: Spacing.sm,
          mainAxisSpacing: Spacing.sm,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _ProductCard(
            product: product,
            onTap: () => onProductTap(product),
            langCode: langCode,
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.langCode,
  });

  final ProductEntity product;
  final VoidCallback onTap;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Spacing.md),
        ),
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                product.name,
                style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              PriceHelper.format(
                PriceHelper.fromDouble(product.price),
                languageCode: langCode,
              ),
              style: TextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesStrip extends StatelessWidget {
  const _FavoritesStrip({
    super.key,
    required this.favorites,
    required this.onProductTap,
    required this.langCode,
    required this.nodeFor,
  });

  final List<ProductEntity> favorites;
  final ValueChanged<ProductEntity> onProductTap;
  final String langCode;
  final FocusNode? Function(String barcode) nodeFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm,
          Spacing.sm,
          Spacing.sm,
          0,
        ),
        itemCount: favorites.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final product = favorites[index];
          final node = nodeFor(product.barcode);
          return Focus(
            focusNode: node,
            child: InkWell(
              onTap: () => onProductTap(product),
              borderRadius: BorderRadius.circular(Spacing.md),
              child: Container(
                width: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Spacing.md),
                ),
                padding: const EdgeInsets.all(Spacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: TextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PriceHelper.format(
                        PriceHelper.fromDouble(product.price),
                        languageCode: langCode,
                      ),
                      style: TextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
