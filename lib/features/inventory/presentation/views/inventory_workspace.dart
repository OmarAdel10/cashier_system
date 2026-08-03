import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/shortcuts/helpers/key_binding_parser.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../widgets/product_card.dart';
import '../widgets/product_column.dart';
import 'product_form_dialog.dart';

class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({super.key});

  @override Widget build(BuildContext context) {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();
    return BlocBuilder<InventoryBloc, InventoryState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.searchQuery != curr.searchQuery ||
          prev.searchResults != curr.searchResults ||
          prev.inventoryMap != curr.inventoryMap,
      builder: (context, state) {
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
    final allProducts = state.searchQuery.isNotEmpty ? state.searchResults : state.inventoryMap.values.toList();
    if (allProducts.isEmpty) return AppEmpty(
      icon: PhosphorIcons.package,
      headline: t.translate('state.empty.inventory', languageCode: langCode),
      body: t.translate('state.empty.inventory.action', languageCode: langCode),
    );

    if (state.searchQuery.isNotEmpty) {
      final products = allProducts;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i], t: t, langCode: langCode,
            onEdit: () => _editProduct(context, products[i]),
            onDelete: () => _deleteProduct(context, products[i], t, langCode),
          ),
        ),
      );
    }

    final products = allProducts;
    final normalItems = products.where((p) => !p.isQuickTile).toList();
    final quickItems = products.where((p) => p.isQuickTile).toList();

    if (normalItems.isEmpty && quickItems.isEmpty) return AppEmpty(
      icon: PhosphorIcons.package,
      headline: t.translate('state.empty.inventory', languageCode: langCode),
      body: t.translate('state.empty.inventory.action', languageCode: langCode),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ProductColumn(
            title: t.translate('inventory.normal', languageCode: langCode),
            products: normalItems,
            t: t, langCode: langCode,
            onEdit: (p) => _editProduct(context, p),
            onDelete: (p) => _deleteProduct(context, p, t, langCode),
          )),
          const SizedBox(width: 16),
          if (quickItems.isNotEmpty)
            Expanded(child: ProductColumn(
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

  void _addProduct(BuildContext context) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: const ProductFormDialog()));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, purchasePrice: r.purchasePrice, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex, notes: r.notes));
  }

  void _editProduct(BuildContext context, ProductEntity product) async {
    final r = await showDialog<ProductEntity>(context: context, builder: (_) => BlocProvider.value(value: context.read<InventoryBloc>(), child: ProductFormDialog(product: product)));
    if (r != null && context.mounted) context.read<InventoryBloc>().add(AddProduct(barcode: r.barcode, name: r.name, price: r.price, purchasePrice: r.purchasePrice, stock: r.stock, isQuickTile: r.isQuickTile, tileColorHex: r.tileColorHex, notes: r.notes));
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

class _InventorySearchDelegate extends SearchDelegate {
  final LocalizationService _t;
  final String _langCode;

  _InventorySearchDelegate(this._t, this._langCode);

  @override String get searchFieldLabel => _t.translate('search.hint', languageCode: _langCode);
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(PhosphorIcons.x), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(PhosphorIcons.arrowLeft), onPressed: () => close(context, null));

  @override Widget buildResults(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return _ClearShortcutHandler(
      onClear: () => query = '',
      child: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (prev, curr) =>
            prev.searchQuery != curr.searchQuery ||
            !listEquals(prev.searchResults, curr.searchResults),
        builder: (c, s) {
        if (s.searchResults.isEmpty) return Center(child: Text(_t.translate('search.noResults', languageCode: _langCode, params: [query]), style: TextStyle(color: Colors.grey.shade600)));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length, itemBuilder: (_, i) => ListTile(title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode)));
      }),
    );
  }

  @override Widget buildSuggestions(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return _ClearShortcutHandler(
      onClear: () => query = '',
      child: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (prev, curr) =>
            prev.searchQuery != curr.searchQuery ||
            !listEquals(prev.searchResults, curr.searchResults),
        builder: (c, s) {
        if (query.isEmpty) return const SizedBox.shrink();
        if (s.searchResults.isEmpty) return Center(child: Text(_t.translate('search.noSuggestions', languageCode: _langCode, params: [query]), style: TextStyle(color: Colors.grey.shade600)));
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.searchResults.length,
          itemBuilder: (_, i) => ListTile(leading: const Icon(PhosphorIcons.package), title: Text(s.searchResults[i].name), subtitle: Text(s.searchResults[i].barcode),
            onTap: () { query = s.searchResults[i].name; showResults(context); }));
      }),
    );
  }
}

class _ClearShortcutHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback onClear;

  const _ClearShortcutHandler({required this.child, required this.onClear});

  @override
  State<_ClearShortcutHandler> createState() => _ClearShortcutHandlerState();
}

class _ClearShortcutHandlerState extends State<_ClearShortcutHandler> {
  List<SingleActivator>? _activators;
  StreamSubscription? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadActivators();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _settingsSubscription = context.read<SettingsBloc>().stream.listen((_) {
      _loadActivators();
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  void _loadActivators() {
    try {
      final bindings =
          context.read<SettingsBloc>().state.settings.customBindings;
      _activators = (bindings['search.clear'] ?? [])
          .map((combo) => parseKeyCombo(combo))
          .whereType<SingleActivator>()
          .toList();
    } catch (_) {
      _activators = [];
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_activators == null) return false;
    for (final a in _activators!) {
      if (event.logicalKey != a.trigger) continue;
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      if (a.control &&
          !pressed.contains(LogicalKeyboardKey.controlLeft) &&
          !pressed.contains(LogicalKeyboardKey.controlRight)) continue;
      if (a.shift &&
          !pressed.contains(LogicalKeyboardKey.shiftLeft) &&
          !pressed.contains(LogicalKeyboardKey.shiftRight)) continue;
      if (a.alt &&
          !pressed.contains(LogicalKeyboardKey.altLeft) &&
          !pressed.contains(LogicalKeyboardKey.altRight)) continue;
      if (a.meta &&
          !pressed.contains(LogicalKeyboardKey.metaLeft) &&
          !pressed.contains(LogicalKeyboardKey.metaRight)) continue;
      widget.onClear();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
