import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import 'product_form_dialog.dart';

class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({super.key});

  @override Widget build(BuildContext context) {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (context, state) {
      final body = switch (state.status) {
        InventoryStatus.loading || InventoryStatus.initial => AppLoading(
          message: t.translate('state.loading.inventory', languageCode: langCode),
        ),
        InventoryStatus.error => AppError(
          headline: t.translate('inventory', languageCode: langCode),
          body: state.failure?.message ?? t.translate('state.error.inventory', languageCode: langCode),
          actionLabel: t.translate('state.error.retry', languageCode: langCode),
          onAction: () => context.read<InventoryBloc>().add(const LoadInventory()),
        ),
        InventoryStatus.ready => _buildContent(context, state, t, langCode),
      };
      return Scaffold(
        body: SectionCard(
          title: t.translate('inventory', languageCode: langCode),
          actions: [
            IconButton(icon: const Icon(PhosphorIcons.magnifyingGlass), onPressed: () => showSearch(context: context, delegate: _InventorySearchDelegate(t, langCode))),
            IconButton(icon: const Icon(PhosphorIcons.plus), onPressed: () => _addProduct(context)),
          ],
          mainAxisSize: MainAxisSize.max,
          child: body,
        ),
      );
    });
  }

  Widget _buildContent(BuildContext context, InventoryState state, LocalizationService t, String langCode) {
    final products = state.searchQuery.isNotEmpty ? state.searchResults : state.inventoryMap.values.toList();
    if (products.isEmpty) return _emptyState(t, langCode);

    if (state.searchQuery.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductCard(
            product: products[i], t: t, langCode: langCode,
            onEdit: () => _editProduct(context, products[i]),
            onDelete: () => _deleteProduct(context, products[i], t, langCode),
          ),
        ),
      );
    }

    final normalItems = products.where((p) => !p.isQuickTile).toList();
    final quickItems = products.where((p) => p.isQuickTile).toList();

    if (normalItems.isEmpty && quickItems.isEmpty) return _emptyState(t, langCode);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ProductColumn(
            title: t.translate('inventory.normal', languageCode: langCode),
            products: normalItems,
            t: t, langCode: langCode,
            onEdit: (p) => _editProduct(context, p),
            onDelete: (p) => _deleteProduct(context, p, t, langCode),
          )),
          const SizedBox(width: 16),
          if (quickItems.isNotEmpty)
            Expanded(child: _ProductColumn(
              title: t.translate('inventory.quickTiles', languageCode: langCode),
              products: quickItems,
              t: t, langCode: langCode,
              onEdit: (p) => _editProduct(context, p),
              onDelete: (p) => _deleteProduct(context, p, t, langCode),
            )),
        ],
      ),
    );
  }

  Widget _emptyState(LocalizationService t, String langCode) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(PhosphorIcons.package, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16), Text(t.translate('state.empty.inventory', languageCode: langCode), style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 8), Text(t.translate('state.empty.inventory.action', languageCode: langCode), style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ]));
  }

  void _addProduct(BuildContext context) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: const ProductFormDialog()));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex));
  }

  void _editProduct(BuildContext context, ProductEntity product) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: ProductFormDialog(product: product)));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex));
  }

  void _deleteProduct(BuildContext context, ProductEntity product, LocalizationService t, String langCode) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(t.translate('inventory.delete.title', languageCode: langCode)),
      content: Text(t.translate('inventory.delete.confirm', languageCode: langCode, params: [product.name])),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.translate('cancel', languageCode: langCode))),
        FilledButton(onPressed: () { Navigator.of(ctx).pop(); context.read<InventoryBloc>().add(DeleteProduct(product.barcode)); },
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: Text(t.translate('inventory.delete.btn', languageCode: langCode)))],
    ));
  }
}

class _ProductColumn extends StatelessWidget {
  final String title;
  final List<ProductEntity> products;
  final LocalizationService t;
  final String langCode;
  final void Function(ProductEntity) onEdit, onDelete;

  const _ProductColumn({
    required this.title,
    required this.products,
    required this.t,
    required this.langCode,
    required this.onEdit,
    required this.onDelete,
  });

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${products.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: products.isEmpty
              ? Center(child: Text(t.translate('inventory.column.empty', languageCode: langCode), style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (_, i) => _ProductCard(
                    product: products[i], t: t, langCode: langCode,
                    onEdit: () => onEdit(products[i]),
                    onDelete: () => onDelete(products[i]),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductEntity product; final VoidCallback onEdit, onDelete;
  final LocalizationService t; final String langCode;
  const _ProductCard({required this.product, required this.t, required this.langCode, required this.onEdit, required this.onDelete});

  @override Widget build(BuildContext context) {
    final priceStr = langCode == 'ar'
      ? '${product.price.toStringAsFixed(2)} ج.م'
      : 'EGP ${product.price.toStringAsFixed(2)}';
    final stockStr = product.stock.toString();
    return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
      leading: product.isQuickTile && product.tileColorHex != null
        ? Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(int.parse(product.tileColorHex!.replaceFirst('#', '0xFF'))), borderRadius: BorderRadius.circular(8)),
            child: const Icon(PhosphorIcons.package, color: Colors.white))
        : const Icon(PhosphorIcons.package, size: 32),
      title: Text(product.name),
      subtitle: Text(t.translate('product.card.subtitle', languageCode: langCode, params: [product.barcode, priceStr, stockStr])),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(PhosphorIcons.pencil), onPressed: onEdit),
        IconButton(icon: Icon(PhosphorIcons.trash, color: Theme.of(context).colorScheme.error), onPressed: onDelete),
      ]),
    ));
  }
}

class _InventorySearchDelegate extends SearchDelegate {
  final LocalizationService _t;
  final String _langCode;

  _InventorySearchDelegate(this._t, this._langCode);

  @override String get searchFieldLabel => _t.translate('search.hint', languageCode: _langCode);
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(PhosphorIcons.x), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(PhosphorIcons.arrowLeft), onPressed: () => close(context, null));

  @override Widget buildResults(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (c, s) {
      if (s.searchResults.isEmpty) return Center(child: Text(_t.translate('search.noResults', languageCode: _langCode, params: [query]), style: TextStyle(color: Colors.grey.shade600)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length, itemBuilder: (_, i) => ListTile(title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode)));
    });
  }

  @override Widget buildSuggestions(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (c, s) {
      if (query.isEmpty) return const SizedBox.shrink();
      if (s.searchResults.isEmpty) return Center(child: Text(_t.translate('search.noSuggestions', languageCode: _langCode, params: [query]), style: TextStyle(color: Colors.grey.shade600)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length,
        itemBuilder: (_, i) => ListTile(leading: const Icon(PhosphorIcons.package), title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode),
          onTap: () { query = s.searchResults[i].name; showResults(context); }));
    });
  }
}
