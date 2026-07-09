import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import 'product_form_dialog.dart';

class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({super.key});

  @override Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (context, state) {
      final body = switch (state.status) {
        InventoryStatus.loading || InventoryStatus.initial => const AppLoading(message: 'Loading...'),
        InventoryStatus.error => AppError(headline: 'Inventory', body: state.failure?.message ?? 'Failed to load inventory', actionLabel: 'Retry',
            onAction: () => context.read<InventoryBloc>().add(const LoadInventory())),
        InventoryStatus.ready => _buildContent(context, state),
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory'), actions: [
          IconButton(icon: const Icon(PhosphorIcons.magnifyingGlass), onPressed: () => showSearch(context: context, delegate: _InventorySearchDelegate())),
          IconButton(icon: const Icon(PhosphorIcons.plus), onPressed: () => _addProduct(context)),
        ]),
        body: body,
      );
    });
  }

  Widget _buildContent(BuildContext context, InventoryState state) {
    final products = state.searchQuery.isNotEmpty ? state.searchResults : state.inventoryMap.values.toList();
    if (products.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(PhosphorIcons.package, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16), Text('No products yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 8), Text('Tap + to add your first product', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ]));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: products.length,
      itemBuilder: (_, i) => _ProductCard(product: products[i], onEdit: () => _editProduct(context, products[i]), onDelete: () => _deleteProduct(context, products[i])));
  }

  void _addProduct(BuildContext context) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: const ProductFormDialog()));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex));
  }

  void _editProduct(BuildContext context, ProductEntity product) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: ProductFormDialog(product: product)));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex));
  }

  void _deleteProduct(BuildContext context, ProductEntity product) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Product'), content: Text('Delete "${product.name}"?'),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () { Navigator.of(ctx).pop(); context.read<InventoryBloc>().add(DeleteProduct(product.barcode)); },
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Delete'))],
    ));
  }
}

class _ProductCard extends StatelessWidget {
  final ProductEntity product; final VoidCallback onEdit, onDelete;
  const _ProductCard({required this.product, required this.onEdit, required this.onDelete});

  @override Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
      leading: product.isQuickTile && product.tileColorHex != null
        ? Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(int.parse(product.tileColorHex!.replaceFirst('#', '0xFF'))), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.shopping_bag, color: Colors.white))
        : const Icon(PhosphorIcons.package, size: 32),
      title: Text(product.name),
      subtitle: Text('${product.barcode}  •  \$${product.price.toStringAsFixed(2)}  •  Stock: ${product.stock}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (product.isQuickTile) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(PhosphorIcons.star, size: 18)),
        IconButton(icon: const Icon(PhosphorIcons.pencil), onPressed: onEdit),
        IconButton(icon: Icon(PhosphorIcons.trash, color: Theme.of(context).colorScheme.error), onPressed: onDelete),
      ]),
    ));
  }
}

class _InventorySearchDelegate extends SearchDelegate {
  @override String get searchFieldLabel => 'Search by name or barcode';
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(PhosphorIcons.x), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(PhosphorIcons.arrowLeft), onPressed: () => close(context, null));

  @override Widget buildResults(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (c, s) {
      if (s.searchResults.isEmpty) return Center(child: Text('No results for "$query"', style: TextStyle(color: Colors.grey.shade600)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length, itemBuilder: (_, i) => ListTile(title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode)));
    });
  }

  @override Widget buildSuggestions(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return BlocBuilder<InventoryBloc, InventoryState>(builder: (c, s) {
      if (query.isEmpty) return const SizedBox.shrink();
      if (s.searchResults.isEmpty) return Center(child: Text('No suggestions for "$query"', style: TextStyle(color: Colors.grey.shade600)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length,
        itemBuilder: (_, i) => ListTile(leading: const Icon(PhosphorIcons.package), title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode),
          onTap: () { query = s.searchResults[i].name; showResults(context); }));
    });
  }
}
