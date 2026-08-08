import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/checkout/domain/entities/station_entity.dart';
import '../../../../features/checkout/domain/helpers/price_helper.dart';
import '../../../../features/checkout/presentation/bloc/station_bloc.dart';
import '../../../../features/checkout/presentation/bloc/station_event.dart';
import '../../../../features/checkout/presentation/bloc/station_state.dart';
import '../../../../features/checkout/presentation/widgets/station_form_dialog.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/shortcuts/helpers/key_binding_parser.dart';
import '../../data/repositories/category_repository.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../widgets/product_card.dart';
import '../widgets/product_column.dart';
import '../widgets/category_management_dialog.dart';
import 'product_form_dialog.dart';

class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state.settings;
    final langCode = settings.languageCode;
    final t = LocalizationService();
    final businessType = BusinessType.fromId(settings.businessType);
    final isTimeBilling = businessType.isTimeBilling;
    return BlocBuilder<InventoryBloc, InventoryState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.searchQuery != curr.searchQuery ||
          prev.searchResults != curr.searchResults ||
          prev.inventoryMap != curr.inventoryMap,
      builder: (context, state) {
        final body = switch (state.status) {
          InventoryStatus.loading || InventoryStatus.initial => AppLoading(
            message: t.translate(
              'state.loading.inventory',
              languageCode: langCode,
            ),
          ),
          InventoryStatus.error => AppError(
            headline: t.translate('inventory', languageCode: langCode),
            body:
                state.failure?.message ??
                t.translate('state.error.inventory', languageCode: langCode),
            actionLabel: t.translate(
              'state.error.retry',
              languageCode: langCode,
            ),
            onAction: () =>
                context.read<InventoryBloc>().add(const LoadInventory()),
          ),
          InventoryStatus.ready =>
            isTimeBilling
                ? _buildStations(context, t, langCode)
                : businessType.hasCategories
                ? _buildFnbContent(context, state, t, langCode)
                : _buildContent(context, state, t, langCode),
        };
        return Scaffold(
          body: SectionCard(
            title: t.translate('inventory', languageCode: langCode),
            actions: [
              if (!isTimeBilling) ...[
                IconButton(
                  icon: const Icon(PhosphorIcons.magnifyingGlass),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: _InventorySearchDelegate(t, langCode),
                  ),
                ),
                if (BusinessType.fromId(
                  context.read<SettingsBloc>().state.settings.businessType,
                ).hasCategories)
                  IconButton(
                    icon: const Icon(PhosphorIcons.folders),
                    tooltip: t.translate(
                      'inventory.category.manage',
                      languageCode: langCode,
                    ),
                    onPressed: () => _manageCategories(context),
                  ),
              ],
              IconButton(
                icon: const Icon(PhosphorIcons.plus),
                onPressed: () =>
                    isTimeBilling ? _addStation(context) : _addProduct(context),
              ),
            ],
            mainAxisSize: MainAxisSize.max,
            child: body,
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    InventoryState state,
    LocalizationService t,
    String langCode,
  ) {
    final allProducts = state.searchQuery.isNotEmpty
        ? state.searchResults
        : state.inventoryMap.values.toList();
    if (allProducts.isEmpty)
      return AppEmpty(
        icon: PhosphorIcons.package,
        headline: t.translate('state.empty.inventory', languageCode: langCode),
        body: t.translate(
          'state.empty.inventory.action',
          languageCode: langCode,
        ),
      );

    if (state.searchQuery.isNotEmpty) {
      final products = allProducts;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i],
            t: t,
            langCode: langCode,
            onEdit: () => _editProduct(context, products[i]),
            onDelete: () => _deleteProduct(context, products[i], t, langCode),
          ),
        ),
      );
    }

    final products = allProducts;
    final normalItems = products.where((p) => !p.isQuickTile).toList();
    final quickItems = products.where((p) => p.isQuickTile).toList();

    if (normalItems.isEmpty && quickItems.isEmpty)
      return AppEmpty(
        icon: PhosphorIcons.package,
        headline: t.translate('state.empty.inventory', languageCode: langCode),
        body: t.translate(
          'state.empty.inventory.action',
          languageCode: langCode,
        ),
      );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ProductColumn(
              title: t.translate('inventory.normal', languageCode: langCode),
              products: normalItems,
              t: t,
              langCode: langCode,
              onEdit: (p) => _editProduct(context, p),
              onDelete: (p) => _deleteProduct(context, p, t, langCode),
            ),
          ),
          const SizedBox(width: 16),
          if (quickItems.isNotEmpty)
            Expanded(
              child: ProductColumn(
                title: t.translate(
                  'inventory.quickTiles',
                  languageCode: langCode,
                ),
                products: quickItems,
                t: t,
                langCode: langCode,
                onEdit: (p) => _editProduct(context, p),
                onDelete: (p) => _deleteProduct(context, p, t, langCode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFnbContent(
    BuildContext context,
    InventoryState state,
    LocalizationService t,
    String langCode,
  ) {
    final allProducts = state.searchQuery.isNotEmpty
        ? state.searchResults
        : state.inventoryMap.values.toList();
    if (allProducts.isEmpty)
      return AppEmpty(
        icon: PhosphorIcons.package,
        headline: t.translate('state.empty.inventory', languageCode: langCode),
        body: t.translate(
          'state.empty.inventory.action',
          languageCode: langCode,
        ),
      );

    if (state.searchQuery.isNotEmpty) {
      final products = allProducts;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i],
            t: t,
            langCode: langCode,
            onEdit: () => _editProduct(context, products[i]),
            onDelete: () => _deleteProduct(context, products[i], t, langCode),
          ),
        ),
      );
    }

    final products = allProducts;
    final categorized = products
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .toList();
    final uncategorized = products
        .where((p) => p.category == null || p.category!.isEmpty)
        .toList();
    final favorites = products.where((p) => p.isQuickTile).toList();

    if (products.isEmpty)
      return AppEmpty(
        icon: PhosphorIcons.package,
        headline: t.translate('state.empty.inventory', languageCode: langCode),
        body: t.translate(
          'state.empty.inventory.action',
          languageCode: langCode,
        ),
      );

    final settings = context.watch<SettingsBloc>().state.settings;
    final favoritesStripEnabled = settings.favoritesStripEnabled;
    final categoryOrder = context
        .watch<CategoryBloc>()
        .state
        .categories
        .map((c) => c.name)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CategorizedColumn(
              title: t.translate(
                'inventory.categorized',
                languageCode: langCode,
              ),
              products: categorized,
              categoryOrder: categoryOrder,
              t: t,
              langCode: langCode,
              onEdit: (p) => _editProduct(context, p),
              onDelete: (p) => _deleteProduct(context, p, t, langCode),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ProductColumn(
              title: t.translate(
                'inventory.uncategorized',
                languageCode: langCode,
              ),
              products: uncategorized,
              t: t,
              langCode: langCode,
              onEdit: (p) => _editProduct(context, p),
              onDelete: (p) => _deleteProduct(context, p, t, langCode),
            ),
          ),
          if (favoritesStripEnabled) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ProductColumn(
                title: t.translate(
                  'inventory.favorites',
                  languageCode: langCode,
                ),
                products: favorites,
                t: t,
                langCode: langCode,
                onEdit: (p) => _editProduct(context, p),
                onDelete: (p) => _deleteProduct(context, p, t, langCode),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStations(
    BuildContext context,
    LocalizationService t,
    String langCode,
  ) {
    return BlocBuilder<StationBloc, StationState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          !listEquals(prev.stations, curr.stations),
      builder: (context, state) {
        if (state.status == StationBlocStatus.error) {
          return AppError(
            headline: t.translate('inventory', languageCode: langCode),
            body: state.failure?.message ?? '',
            actionLabel: t.translate(
              'state.error.retry',
              languageCode: langCode,
            ),
            onAction: () =>
                context.read<StationBloc>().add(const LoadStations()),
          );
        }
        if (state.status == StationBlocStatus.loading ||
            state.status == StationBlocStatus.initial) {
          return AppLoading(
            message: t.translate(
              'state.loading.inventory',
              languageCode: langCode,
            ),
          );
        }
        if (state.stations.isEmpty) {
          return AppEmpty(
            icon: PhosphorIcons.gameController,
            headline: t.translate('station.empty', languageCode: langCode),
            body: t.translate('station.empty.action', languageCode: langCode),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Spacing.md),
          itemCount: state.stations.length,
          separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
          itemBuilder: (context, i) => _StationManagementTile(
            station: state.stations[i],
            t: t,
            langCode: langCode,
            onEdit: () => _editStation(context, state.stations[i]),
            onDelete: () =>
                _deleteStation(context, state.stations[i], t, langCode),
          ),
        );
      },
    );
  }

  Future<void> _addStation(BuildContext context) async {
    final r = await showDialog<StationEntity>(
      context: context,
      builder: (dialogContext) => BlocProvider<SettingsBloc>.value(
        value: context.read<SettingsBloc>(),
        child: const StationFormDialog(),
      ),
    );
    if (r != null && context.mounted)
      context.read<StationBloc>().add(SaveStation(station: r));
  }

  Future<void> _editStation(BuildContext context, StationEntity station) async {
    final r = await showDialog<StationEntity>(
      context: context,
      builder: (dialogContext) => BlocProvider<SettingsBloc>.value(
        value: context.read<SettingsBloc>(),
        child: StationFormDialog(station: station),
      ),
    );
    if (r != null && context.mounted)
      context.read<StationBloc>().add(SaveStation(station: r));
  }

  void _deleteStation(
    BuildContext context,
    StationEntity station,
    LocalizationService t,
    String langCode,
  ) {
    if (station.status != StationStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.translate(
              'station.delete.blocked',
              languageCode: langCode,
              params: [station.name],
            ),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t.translate('station.delete.title', languageCode: langCode),
        ),
        content: Text(
          t.translate(
            'station.delete.confirm',
            languageCode: langCode,
            params: [station.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<StationBloc>().add(
                DeleteStation(stationId: station.id),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              t.translate('inventory.delete.btn', languageCode: langCode),
            ),
          ),
        ],
      ),
    );
  }

  void _addProduct(BuildContext context) async {
    final r = await showDialog<ProductEntity>(
      context: context,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider<InventoryBloc>.value(
            value: context.read<InventoryBloc>(),
          ),
          BlocProvider<CategoryBloc>(create: (ctx) => _buildCategoryBloc(ctx)),
        ],
        child: const ProductFormDialog(),
      ),
    );
    if (r != null && context.mounted)
      context.read<InventoryBloc>().add(
        AddProduct(
          barcode: r.barcode,
          name: r.name,
          price: r.price,
          purchasePrice: r.purchasePrice,
          stock: r.stock,
          isQuickTile: r.isQuickTile,
          tileColorHex: r.tileColorHex,
          category: r.category,
          notes: r.notes,
        ),
      );
  }

  void _editProduct(BuildContext context, ProductEntity product) async {
    final r = await showDialog<ProductEntity>(
      context: context,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider<InventoryBloc>.value(
            value: context.read<InventoryBloc>(),
          ),
          BlocProvider<CategoryBloc>(create: (ctx) => _buildCategoryBloc(ctx)),
        ],
        child: ProductFormDialog(product: product),
      ),
    );
    if (r != null && context.mounted)
      context.read<InventoryBloc>().add(
        AddProduct(
          barcode: r.barcode,
          name: r.name,
          price: r.price,
          purchasePrice: r.purchasePrice,
          stock: r.stock,
          isQuickTile: r.isQuickTile,
          tileColorHex: r.tileColorHex,
          category: r.category,
          notes: r.notes,
        ),
      );
  }

  void _manageCategories(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider<CategoryBloc>(
        create: (ctx) => _buildCategoryBloc(ctx),
        child: const CategoryManagementDialog(),
      ),
    );
  }

  void _deleteProduct(
    BuildContext context,
    ProductEntity product,
    LocalizationService t,
    String langCode,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t.translate('inventory.delete.title', languageCode: langCode),
        ),
        content: Text(
          t.translate(
            'inventory.delete.confirm',
            languageCode: langCode,
            params: [product.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<InventoryBloc>().add(DeleteProduct(product.barcode));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              t.translate('inventory.delete.btn', languageCode: langCode),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySearchDelegate extends SearchDelegate {
  final LocalizationService _t;
  final String _langCode;

  _InventorySearchDelegate(this._t, this._langCode);

  @override
  String get searchFieldLabel =>
      _t.translate('search.hint', languageCode: _langCode);
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(PhosphorIcons.x), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(PhosphorIcons.arrowLeft),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return _ClearShortcutHandler(
      onClear: () => query = '',
      child: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (prev, curr) =>
            prev.searchQuery != curr.searchQuery ||
            !listEquals(prev.searchResults, curr.searchResults),
        builder: (c, s) {
          if (s.searchResults.isEmpty)
            return Center(
              child: Text(
                _t.translate(
                  'search.noResults',
                  languageCode: _langCode,
                  params: [query],
                ),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.searchResults.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(s.searchResults[i].name),
              subtitle: Text(s.searchResults[i].barcode),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    context.read<InventoryBloc>().add(SearchProducts(query));
    return _ClearShortcutHandler(
      onClear: () => query = '',
      child: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (prev, curr) =>
            prev.searchQuery != curr.searchQuery ||
            !listEquals(prev.searchResults, curr.searchResults),
        builder: (c, s) {
          if (query.isEmpty) return const SizedBox.shrink();
          if (s.searchResults.isEmpty)
            return Center(
              child: Text(
                _t.translate(
                  'search.noSuggestions',
                  languageCode: _langCode,
                  params: [query],
                ),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: s.searchResults.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(PhosphorIcons.package),
              title: Text(s.searchResults[i].name),
              subtitle: Text(s.searchResults[i].barcode),
              onTap: () {
                query = s.searchResults[i].name;
                showResults(context);
              },
            ),
          );
        },
      ),
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
      final bindings = context
          .read<SettingsBloc>()
          .state
          .settings
          .customBindings;
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
          !pressed.contains(LogicalKeyboardKey.controlRight))
        continue;
      if (a.shift &&
          !pressed.contains(LogicalKeyboardKey.shiftLeft) &&
          !pressed.contains(LogicalKeyboardKey.shiftRight))
        continue;
      if (a.alt &&
          !pressed.contains(LogicalKeyboardKey.altLeft) &&
          !pressed.contains(LogicalKeyboardKey.altRight))
        continue;
      if (a.meta &&
          !pressed.contains(LogicalKeyboardKey.metaLeft) &&
          !pressed.contains(LogicalKeyboardKey.metaRight))
        continue;
      widget.onClear();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

CategoryBloc _buildCategoryBloc(BuildContext context) {
  final businessType = BusinessType.fromId(
    context.read<SettingsBloc>().state.settings.businessType,
  );
  return CategoryBloc(
    repository: CategoryRepository(
      businessType: businessType,
      box: Hive.box<List>('product_categories'),
    ),
  )..add(const LoadCategories());
}

class _StationManagementTile extends StatelessWidget {
  final StationEntity station;
  final LocalizationService t;
  final String langCode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StationManagementTile({
    required this.station,
    required this.t,
    required this.langCode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = station.stationType == StationType.playstation
        ? t.translate('station.form.typePlaystation', languageCode: langCode)
        : t.translate('station.form.typeTable', languageCode: langCode);

    final statusLabel = switch (station.status) {
      StationStatus.available => t.translate(
        'station.status.available',
        languageCode: langCode,
      ),
      StationStatus.active => t.translate(
        'station.status.active',
        languageCode: langCode,
      ),
      StationStatus.overtime => t.translate(
        'station.status.overtime',
        languageCode: langCode,
      ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(PhosphorIcons.gameController),
        title: Text(station.name, style: TextStyles.heading3),
        subtitle: Text(
          '$typeLabel • ${station.parentCategory} • $statusLabel\n'
          '${t.translate('station.tierNormal', languageCode: langCode)}: '
          '${PriceHelper.format(PriceHelper.fromDouble(station.normalHourlyRate), languageCode: langCode)}/hr • '
          '${t.translate('station.tierMulti', languageCode: langCode)}: '
          '${PriceHelper.format(PriceHelper.fromDouble(station.multiHourlyRate), languageCode: langCode)}/hr',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(PhosphorIcons.pencilSimple),
              tooltip: t.translate(
                'station.form.editTitle',
                languageCode: langCode,
              ),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(PhosphorIcons.trash),
              tooltip: t.translate(
                'inventory.delete.btn',
                languageCode: langCode,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorizedColumn extends StatelessWidget {
  final String title;
  final List<ProductEntity> products;
  final List<String> categoryOrder;
  final LocalizationService t;
  final String langCode;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onDelete;

  const _CategorizedColumn({
    required this.title,
    required this.products,
    required this.categoryOrder,
    required this.t,
    required this.langCode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group products by category, ordered by categoryOrder first, then any
    // unknown categories in encounter order.
    final grouped = <String, List<ProductEntity>>{};
    for (final p in products) {
      final category = p.category ?? '';
      grouped.putIfAbsent(category, () => []).add(p);
    }
    final known = categoryOrder.where(grouped.containsKey).toList();
    final unknown = grouped.keys
        .where((c) => !categoryOrder.contains(c))
        .toList();
    final ordered = [...known, ...unknown];

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
          Text(
            '$title (${products.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Text(
                      t.translate(
                        'inventory.column.empty',
                        languageCode: langCode,
                      ),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: ordered.length,
                    itemBuilder: (_, i) {
                      final category = ordered[i];
                      final items = grouped[category]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          ...items.map(
                            (p) => ProductCard(
                              product: p,
                              t: t,
                              langCode: langCode,
                              onEdit: () => onEdit(p),
                              onDelete: () => onDelete(p),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
