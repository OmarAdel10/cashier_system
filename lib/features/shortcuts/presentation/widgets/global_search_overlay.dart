import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../checkout/presentation/bloc/checkout_bloc.dart';
import '../../../checkout/presentation/bloc/checkout_event.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../helpers/key_binding_parser.dart';
import '../../intents.dart';
import '../../default_bindings.dart';

class SearchState {
  final List<ProductEntity> results;
  final bool hasSearched;

  const SearchState({this.results = const [], this.hasSearched = false});
}

class GlobalSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueNotifier<String> barcodeInjectionNotifier;

  const GlobalSearchOverlay({
    super.key,
    required this.onClose,
    required this.barcodeInjectionNotifier,
  });

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _searchStateNotifier = ValueNotifier<SearchState>(const SearchState());
  late final String _langCode;
  late final Map<String, List<String>> _customBindings;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsBloc>().state.settings;
    _langCode = settings.languageCode;
    _customBindings = settings.customBindings;
    _focusNode.requestFocus();
    widget.barcodeInjectionNotifier.addListener(_onBarcodeInjected);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchStateNotifier.dispose();
    widget.barcodeInjectionNotifier.removeListener(_onBarcodeInjected);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBarcodeInjected() {
    final barcode = widget.barcodeInjectionNotifier.value;
    if (barcode.isEmpty) return;
    _searchController.text = barcode;
    _performSearch(barcode);
    widget.barcodeInjectionNotifier.value = '';
  }

  void _onSearchChanged() {
    _performSearch(_searchController.text);
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchStateNotifier.value = const SearchState();
      return;
    }

    final inventoryState = context.read<InventoryBloc>().state;
    final q = query.toLowerCase();
    _searchStateNotifier.value = SearchState(
      results: inventoryState.inventoryMap.values
          .where(
            (p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q),
          )
          .toList(),
      hasSearched: true,
    );
  }

  void _selectProduct(ProductEntity product) {
    context.read<CheckoutBloc>().add(
      AddToCart(
        barcode: product.barcode,
        name: product.name,
        unitPricePiastres: PriceHelper.fromDouble(product.price),
      ),
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final colorScheme = Theme.of(context).colorScheme;

    final shortcuts = <ShortcutActivator, Intent>{};
    for (final combo
        in _customBindings['search.clear'] ??
            defaultBindings['search.clear'] ??
            <String>[]) {
      shortcuts[parseKeyCombo(combo)] = const ClearSearchIntent();
    }
    // Add search.toggle to close overlay with F5 (or other bound key)
    for (final combo
        in _customBindings['search.toggle'] ??
            defaultBindings['search.toggle'] ??
            <String>[]) {
      // Skip single-char printable combos like '/' to avoid conflicts with typing
      if (combo.length == 1 &&
          !combo.startsWith('ctrl') &&
          !combo.startsWith('alt') &&
          !combo.startsWith('shift') &&
          !combo.startsWith('meta')) {
        continue;
      }
      shortcuts[parseKeyCombo(combo, includeRepeats: false)] =
          const ToggleSearchOverlayIntent();
    }

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: colorScheme.scrim.withValues(alpha: 0.5),
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                event is KeyDownEvent) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Shortcuts(
            shortcuts: shortcuts,
            child: Actions(
              actions: {
                ClearSearchIntent: CallbackAction<ClearSearchIntent>(
                  onInvoke: (_) {
                    _searchController.clear();
                    _focusNode.requestFocus();
                    return null;
                  },
                ),
                ToggleSearchOverlayIntent: CallbackAction(
                  onInvoke: (_) {
                    widget.onClose();
                    return null;
                  },
                ),
              },
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 500,
                    constraints: const BoxConstraints(maxHeight: 600),
                    child: Material(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(Spacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(Spacing.md),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: t.translate(
                                  'search.hint',
                                  languageCode: _langCode,
                                ),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _focusNode.requestFocus();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    Spacing.sm,
                                  ),
                                ),
                              ),
                              onSubmitted: (value) {
                                if (_searchStateNotifier.value.results.length ==
                                    1) {
                                  _selectProduct(
                                    _searchStateNotifier.value.results.first,
                                  );
                                }
                              },
                            ),
                          ),
                          ValueListenableBuilder<SearchState>(
                            valueListenable: _searchStateNotifier,
                            builder: (context, state, _) {
                              if (state.hasSearched && state.results.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(Spacing.lg),
                                  child: Text(
                                    t.translate(
                                      'search.noResults',
                                      languageCode: _langCode,
                                      params: [_searchController.text],
                                    ),
                                    style: TextStyles.body.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              return Flexible(
                                child: ListView.builder(
                                  itemCount: state.results.length,
                                  itemBuilder: (context, index) {
                                    final product = state.results[index];
                                    final langCode = Localizations.localeOf(
                                      context,
                                    ).languageCode;
                                    return ListTile(
                                      leading: const Icon(Icons.inventory_2),
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '${product.barcode}  •  ${PriceHelper.format(PriceHelper.fromDouble(product.price), languageCode: langCode)}',
                                      ),
                                      onTap: () => _selectProduct(product),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
