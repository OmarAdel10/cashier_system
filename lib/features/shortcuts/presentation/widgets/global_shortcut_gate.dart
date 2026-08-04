import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../default_bindings.dart';
import '../../helpers/key_binding_parser.dart';
import '../../intents.dart';
import '../../../auth/domain/entities/nav_destination.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../checkout/presentation/bloc/checkout_bloc.dart';
import '../../../checkout/presentation/bloc/checkout_event.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import 'global_search_overlay.dart';

class GlobalShortcutGate extends StatefulWidget {
  final Widget child;
  final List<NavDestination> allowedDestinations;
  final ValueNotifier<NavDestination> selectedDestination;
  final ValueNotifier<bool> isSearchOpenNotifier;
  final ValueNotifier<String> barcodeInjectionNotifier;
  final VoidCallback? onAddProduct;
  final ValueNotifier<int>? discountFocusTrigger;

  const GlobalShortcutGate({
    super.key,
    required this.child,
    this.allowedDestinations = const [],
    required this.selectedDestination,
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
  final _gateFocusNode = FocusNode(debugLabel: 'shortcutGate');
  FocusNode? _preOverlayFocus;

  /// Restores the focus that was active before the overlay opened.
  ///
  /// The gate node is an ANCESTOR of the barcode scanner and cart table
  /// nodes; focusing it directly would leave those nodes out of the focus
  /// chain and their key handlers would never fire. The workspace node
  /// (scanner/table/typing field) is a descendant of the gate, so
  /// restoring IT keeps both shortcuts and scanning alive.
  void _restoreFocusAfterOverlay() {
    final saved = _preOverlayFocus;
    if (saved != null && saved.context != null) {
      saved.requestFocus();
    } else {
      _gateFocusNode.requestFocus();
    }
    _preOverlayFocus = null;
  }

  void _toggleSearchOverlay() {
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry?.remove();
      _searchOverlayEntry = null;
      widget.isSearchOpenNotifier.value = false;
      _restoreFocusAfterOverlay();
      return;
    }

    _preOverlayFocus = FocusManager.instance.primaryFocus;
    widget.isSearchOpenNotifier.value = true;
    _searchOverlayEntry = OverlayEntry(
      builder: (_) => GlobalSearchOverlay(
        onClose: () {
          _searchOverlayEntry?.remove();
          _searchOverlayEntry = null;
          widget.isSearchOpenNotifier.value = false;
          _restoreFocusAfterOverlay();
        },
        barcodeInjectionNotifier: widget.barcodeInjectionNotifier,
      ),
    );
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  @override
  void dispose() {
    _searchOverlayEntry?.remove();
    _gateFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (prev, curr) =>
          prev.settings.customBindings != curr.settings.customBindings,
      builder: (context, state) {
        return _ShortcutsLayer(
          customBindings: state.settings.customBindings,
          allowedDestinations: widget.allowedDestinations,
          selectedDestination: widget.selectedDestination,
          onToggleSearch: _toggleSearchOverlay,
          onAddProduct: widget.onAddProduct,
          discountFocusTrigger: widget.discountFocusTrigger,
          gateFocusNode: _gateFocusNode,
          child: widget.child,
        );
      },
    );
  }
}

class _ShortcutsLayer extends StatelessWidget {
  final Map<String, List<String>> customBindings;
  final List<NavDestination> allowedDestinations;
  final ValueNotifier<NavDestination> selectedDestination;
  final VoidCallback onToggleSearch;
  final VoidCallback? onAddProduct;
  final ValueNotifier<int>? discountFocusTrigger;
  final FocusNode gateFocusNode;
  final Widget child;

  const _ShortcutsLayer({
    required this.customBindings,
    this.allowedDestinations = const [],
    required this.selectedDestination,
    required this.onToggleSearch,
    this.onAddProduct,
    this.discountFocusTrigger,
    required this.gateFocusNode,
    required this.child,
  });

  bool _isTyping(BuildContext context) {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.findAncestorWidgetOfExactType<TextField>() != null;
  }

  Map<ShortcutActivator, Intent> _buildShortcutMap() {
    final map = <ShortcutActivator, Intent>{};
    final allActions = <String, List<String>>{};
    allActions.addAll(defaultBindings);
    for (final entry in customBindings.entries) {
      allActions[entry.key] = entry.value;
    }
    for (final entry in allActions.entries) {
      // Only navigation tolerates OS key auto-repeat; everything else
      // mutates state (cart, overlay, discount, amount) and must fire once
      // per press even while held.
      final includeRepeats = entry.key.startsWith('nav.');
      for (final combo in entry.value) {
        map[parseKeyCombo(combo, includeRepeats: includeRepeats)] =
            _intentForAction(entry.key);
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
      case 'cart.amount.5eg':
        return const SetAmountPaid5EGIntent();
      case 'cart.amount.10eg':
        return const SetAmountPaid10EGIntent();
      case 'cart.amount.20eg':
        return const SetAmountPaid20EGIntent();
      case 'cart.amount.50eg':
        return const SetAmountPaid50EGIntent();
      case 'cart.amount.100eg':
        return const SetAmountPaid100EGIntent();
      case 'cart.amount.200eg':
        return const SetAmountPaid200EGIntent();
      case 'cart.amount.clear':
        return const ClearAmountPaidIntent();
      default:
        return const NullIntent();
    }
  }

  Map<Type, Action<Intent>> _buildActionsMap(BuildContext context) {
    return <Type, Action<Intent>>{
      NavigateToCheckoutIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (allowedDestinations.contains(NavDestination.checkout)) {
            selectedDestination.value = NavDestination.checkout;
          }
          return null;
        },
      ),
      NavigateToInventoryIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (allowedDestinations.contains(NavDestination.inventory)) {
            selectedDestination.value = NavDestination.inventory;
          }
          return null;
        },
      ),
      NavigateToSalesIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (allowedDestinations.contains(NavDestination.sales)) {
            selectedDestination.value = NavDestination.sales;
          }
          return null;
        },
      ),
      NavigateToSettingsIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (allowedDestinations.contains(NavDestination.settings)) {
            selectedDestination.value = NavDestination.settings;
          }
          return null;
        },
      ),
      ToggleSearchOverlayIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          onToggleSearch();
          return null;
        },
      ),
      ConfirmSaleIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          context.read<CheckoutBloc>().add(const ConfirmSale());
          return null;
        },
      ),
      ActivateQuickTileIntent: CallbackAction<ActivateQuickTileIntent>(
        onInvoke: (intent) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final tiles = context.read<InventoryBloc>().state.quickTileList;
          if (intent.tileIndex < tiles.length) {
            final product = tiles[intent.tileIndex];
            context.read<CheckoutBloc>().add(
              AddToCart(
                barcode: product.barcode,
                name: product.name,
                unitPricePiastres: PriceHelper.fromDouble(product.price),
              ),
            );
          }
          return null;
        },
      ),
      AddProductIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value == NavDestination.inventory) {
            onAddProduct?.call();
          }
          return null;
        },
      ),
      FocusDiscountIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) {
            return null;
          }
          discountFocusTrigger?.value++;
          return null;
        },
      ),
      SetAmountPaid5EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 500));
          return null;
        },
      ),
      SetAmountPaid10EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 1000));
          return null;
        },
      ),
      SetAmountPaid20EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 2000));
          return null;
        },
      ),
      SetAmountPaid50EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 5000));
          return null;
        },
      ),
      SetAmountPaid100EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 10000));
          return null;
        },
      ),
      SetAmountPaid200EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 20000));
          return null;
        },
      ),
      ClearAmountPaidIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (selectedDestination.value != NavDestination.checkout) return null;
          context.read<CheckoutBloc>().add(const ClearAmountPaid());
          return null;
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final shortcutsMap = _buildShortcutMap();
    return Shortcuts(
      shortcuts: shortcutsMap,
      child: Actions(
        dispatcher: null,
        actions: _buildActionsMap(context),
        child: Focus(focusNode: gateFocusNode, child: child),
      ),
    );
  }
}
