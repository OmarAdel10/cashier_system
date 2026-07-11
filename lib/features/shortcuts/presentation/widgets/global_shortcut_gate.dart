import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../default_bindings.dart';
import '../../helpers/key_binding_parser.dart';
import '../../intents.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../checkout/presentation/bloc/checkout_bloc.dart';
import '../../../checkout/presentation/bloc/checkout_event.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import 'global_search_overlay.dart';

class GlobalShortcutGate extends StatefulWidget {
  final Widget child;
  final ValueNotifier<int> selectedIndexNotifier;
  final ValueNotifier<bool> isSearchOpenNotifier;
  final ValueNotifier<String> barcodeInjectionNotifier;
  final VoidCallback? onAddProduct;
  final ValueNotifier<int>? discountFocusTrigger;

  const GlobalShortcutGate({
    super.key,
    required this.child,
    required this.selectedIndexNotifier,
    required this.isSearchOpenNotifier,
    required this.barcodeInjectionNotifier,
    this.onAddProduct,
    this.discountFocusTrigger,
  });

  @override
  State<GlobalShortcutGate> createState() => _GlobalShortcutGateState();
}

class _GlobalShortcutGateState extends State<GlobalShortcutGate> {
  OverlayEntry? _searchOverlayEntry;

  Map<ShortcutActivator, Intent> _buildShortcutMap(
      Map<String, List<String>> customBindings) {
    final map = <ShortcutActivator, Intent>{};
    final allActions = <String, List<String>>{};
    allActions.addAll(defaultBindings);
    for (final entry in customBindings.entries) {
      allActions[entry.key] = entry.value;
    }
    for (final entry in allActions.entries) {
      for (final combo in entry.value) {
        map[parseKeyCombo(combo)] = _intentForAction(entry.key);
      }
    }
    return map;
  }

  Intent _intentForAction(String actionToken) {
    switch (actionToken) {
      case 'nav.checkout':
        return const NavigateToCheckoutIntent();
      case 'nav.inventory':
        return const NavigateToInventoryIntent();
      case 'nav.sales':
        return const NavigateToSalesIntent();
      case 'nav.settings':
        return const NavigateToSettingsIntent();
      case 'search.toggle':
        return const ToggleSearchOverlayIntent();
      case 'cart.confirm':
        return const ConfirmSaleIntent();
      case 'cart.selected.up':
        return const SelectPrevCartItemIntent();
      case 'cart.selected.down':
        return const SelectNextCartItemIntent();
      case 'cart.selected.delete':
        return const RemoveSelectedCartItemIntent();
      case 'cart.quick.1':
        return const ActivateQuickTileIntent(0);
      case 'cart.quick.2':
        return const ActivateQuickTileIntent(1);
      case 'cart.quick.3':
        return const ActivateQuickTileIntent(2);
      case 'cart.quick.4':
        return const ActivateQuickTileIntent(3);
      case 'cart.quick.5':
        return const ActivateQuickTileIntent(4);
      case 'cart.quick.6':
        return const ActivateQuickTileIntent(5);
      case 'cart.quick.7':
        return const ActivateQuickTileIntent(6);
      case 'cart.quick.8':
        return const ActivateQuickTileIntent(7);
      case 'cart.quick.9':
        return const ActivateQuickTileIntent(8);
      case 'cart.quick.10':
        return const ActivateQuickTileIntent(9);
      case 'inventory.addProduct':
        return const AddProductIntent();
      case 'cart.discount':
        return const FocusDiscountIntent();
      default:
        return const ToggleSearchOverlayIntent();
    }
  }

  Map<Type, Action<Intent>> _buildActionsMap() {
    return <Type, Action<Intent>>{
      NavigateToCheckoutIntent: CallbackAction(
        onInvoke: (_) {
          widget.selectedIndexNotifier.value = 0;
          return null;
        },
      ),
      NavigateToInventoryIntent: CallbackAction(
        onInvoke: (_) {
          widget.selectedIndexNotifier.value = 1;
          return null;
        },
      ),
      NavigateToSalesIntent: CallbackAction(
        onInvoke: (_) {
          widget.selectedIndexNotifier.value = 2;
          return null;
        },
      ),
      NavigateToSettingsIntent: CallbackAction(
        onInvoke: (_) {
          widget.selectedIndexNotifier.value = 3;
          return null;
        },
      ),
      ToggleSearchOverlayIntent: CallbackAction(
        onInvoke: (_) {
          _toggleSearchOverlay();
          return null;
        },
      ),
      ConfirmSaleIntent: CallbackAction(
        onInvoke: (_) {
          context.read<CheckoutBloc>().add(const ConfirmSale());
          return null;
        },
      ),
      SelectPrevCartItemIntent: CallbackAction(
        onInvoke: (_) => null,
      ),
      SelectNextCartItemIntent: CallbackAction(
        onInvoke: (_) => null,
      ),
      RemoveSelectedCartItemIntent: CallbackAction(
        onInvoke: (_) => null,
      ),
      ActivateQuickTileIntent: CallbackAction<ActivateQuickTileIntent>(
        onInvoke: (intent) {
          final tiles =
              context.read<InventoryBloc>().state.quickTileList;
          if (intent.tileIndex < tiles.length) {
            final product = tiles[intent.tileIndex];
            context.read<CheckoutBloc>().add(AddToCart(
                  barcode: product.barcode,
                  name: product.name,
                  unitPricePiastres:
                      PriceHelper.fromDouble(product.price),
                ));
          }
          return null;
        },
      ),
      AddProductIntent: CallbackAction(
        onInvoke: (_) {
          widget.onAddProduct?.call();
          return null;
        },
      ),
      FocusDiscountIntent: CallbackAction(
        onInvoke: (_) {
          widget.discountFocusTrigger?.value++;
          return null;
        },
      ),
    };
  }

  void _toggleSearchOverlay() {
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry?.remove();
      _searchOverlayEntry = null;
      widget.isSearchOpenNotifier.value = false;
      return;
    }

    widget.isSearchOpenNotifier.value = true;
    _searchOverlayEntry = OverlayEntry(
      builder: (_) => GlobalSearchOverlay(
        onClose: () {
          _searchOverlayEntry?.remove();
          _searchOverlayEntry = null;
          widget.isSearchOpenNotifier.value = false;
        },
        barcodeInjectionNotifier: widget.barcodeInjectionNotifier,
      ),
    );
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  @override
  void dispose() {
    _searchOverlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final customBindings = state.settings.customBindings;
        final shortcutsMap = _buildShortcutMap(customBindings);

        return Shortcuts(
          shortcuts: shortcutsMap,
          child: Actions(
            dispatcher: null,
            actions: _buildActionsMap(),
            child: widget.child,
          ),
        );
      },
    );
  }
}
