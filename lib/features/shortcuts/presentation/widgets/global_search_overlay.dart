import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../checkout/presentation/bloc/checkout_bloc.dart';
import '../../../checkout/presentation/bloc/checkout_event.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';

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
  List<ProductEntity> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    widget.barcodeInjectionNotifier.addListener(_onBarcodeInjected);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    final inventoryState = context.read<InventoryBloc>().state;
    final q = query.toLowerCase();
    setState(() {
      _results = inventoryState.inventoryMap.values
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.barcode.contains(q))
          .toList();
      _hasSearched = true;
    });
  }

  void _selectProduct(ProductEntity product) {
    context.read<CheckoutBloc>().add(AddToCart(
          barcode: product.barcode,
          name: product.name,
          unitPricePiastres: PriceHelper.fromDouble(product.price),
        ));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 500,
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(Spacing.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search by name or barcode...',
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
                            borderRadius:
                                BorderRadius.circular(Spacing.sm),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (_results.length == 1) {
                            _selectProduct(_results.first);
                          }
                        },
                      ),
                    ),
                    if (_hasSearched && _results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Text(
                          'No products found for "${_searchController.text}"',
                          style: TextStyles.body.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            final langCode =
                                Localizations.localeOf(context)
                                    .languageCode;
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
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
