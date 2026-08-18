import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/shortcuts/presentation/focus_controller.dart';
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
import '../focus_guard.dart';

class GlobalShortcutGate extends StatefulWidget {
  final Widget child;
  final List<NavDestination> allowedDestinations;
  final ValueNotifier<NavDestination> selectedDestination;
  final ValueNotifier<bool> isSearchOpenNotifier;
  final ValueNotifier<String> barcodeInjectionNotifier;
  final VoidCallback? onAddProduct;
  final ValueNotifier<int>? discountFocusTrigger;
  final FocusController? _focusController;

  const GlobalShortcutGate({
    super.key,
    required this.child,
    this.allowedDestinations = const [],
    required this.selectedDestination,
    required this.isSearchOpenNotifier,
    required this.barcodeInjectionNotifier,
    this.onAddProduct,
    this.discountFocusTrigger,
    FocusController? focusController,
  }) : _focusController = focusController;

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
      builder: (_) => FocusGuard(
        controller: widget._focusController,
        child: GlobalSearchOverlay(
          onClose: () {
            _searchOverlayEntry?.remove();
            _searchOverlayEntry = null;
            widget.isSearchOpenNotifier.value = false;
            _restoreFocusAfterOverlay();
          },
          barcodeInjectionNotifier: widget.barcodeInjectionNotifier,
        ),
      ),
    );
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onGlobalFocusChange);
  }

  /// If focus ever goes null (e.g. login screen disposal, route pops,
  /// dialog close), reclaim the active node (scanner or grid) so global
  /// shortcuts keep working without requiring the user to click
  /// something first.
  void _onGlobalFocusChange() {
    if (FocusManager.instance.primaryFocus != null) return;
    widget._focusController?.reclaimOnPrimaryFocusNull();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
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
          focusController: widget._focusController,
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
  final FocusController? focusController;
  final FocusNode gateFocusNode;
  final Widget child;

  const _ShortcutsLayer({
    required this.customBindings,
    this.allowedDestinations = const [],
    required this.selectedDestination,
    required this.onToggleSearch,
    this.onAddProduct,
    this.discountFocusTrigger,
    this.focusController,
    required this.gateFocusNode,
    required this.child,
  });

  bool _isTyping(BuildContext context) {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.findAncestorWidgetOfExactType<TextField>() != null;
  }

  /// Cart-scope actions (confirm, quick tiles, discount, amounts) require the
  /// checkout destination AND an unblocked focus policy (no modal/overlay).
  bool _canUseCart(BuildContext context) {
    if (selectedDestination.value != NavDestination.checkout) return false;
    if (focusController != null &&
        !focusController!.canActivate(FocusZone.cart)) {
      return false;
    }
    return true;
  }

  Map<ShortcutActivator, Intent> _buildShortcutMap() {
    final map = <ShortcutActivator, Intent>{};
    final allActions = <String, List<String>>{};

    // Generate nav F-combos dynamically from allowedDestinations order.
    // F1 → allowedDestinations[0], F2 → [1], F3 → [2]. No F4 — no role
    // has 4 destinations. Custom bindings still override per action-token.
    final navFKeys = ['f1', 'f2', 'f3'];
    for (
      var i = 0;
      i < allowedDestinations.length && i < navFKeys.length;
      i++
    ) {
      final dest = allowedDestinations[i];
      allActions['nav.${dest.name.split('.').last}'] = [navFKeys[i]];
    }

    // Non‑nav default bindings (search, cart, inventory, discount, amounts).
    // Nav entries from defaultBindings are intentionally omitted — they are
    // generated above from the role‑specific allowedDestinations.
    final nonNavDefaults = <String, List<String>>{
      'search.toggle': defaultBindings['search.toggle'] ?? <String>[],
      'cart.confirm': defaultBindings['cart.confirm'] ?? <String>[],
      'cart.discount': defaultBindings['cart.discount'] ?? <String>[],
      'inventory.addProduct':
          defaultBindings['inventory.addProduct'] ?? <String>[],
      'cart.quick.1': defaultBindings['cart.quick.1'] ?? <String>[],
      'cart.quick.2': defaultBindings['cart.quick.2'] ?? <String>[],
      'cart.quick.3': defaultBindings['cart.quick.3'] ?? <String>[],
      'cart.quick.4': defaultBindings['cart.quick.4'] ?? <String>[],
      'cart.quick.5': defaultBindings['cart.quick.5'] ?? <String>[],
      'cart.quick.6': defaultBindings['cart.quick.6'] ?? <String>[],
      'cart.quick.7': defaultBindings['cart.quick.7'] ?? <String>[],
      'cart.quick.8': defaultBindings['cart.quick.8'] ?? <String>[],
      'cart.quick.9': defaultBindings['cart.quick.9'] ?? <String>[],
      'cart.quick.10': defaultBindings['cart.quick.10'] ?? <String>[],
      'cart.amount.5eg': defaultBindings['cart.amount.5eg'] ?? <String>[],
      'cart.amount.10eg': defaultBindings['cart.amount.10eg'] ?? <String>[],
      'cart.amount.20eg': defaultBindings['cart.amount.20eg'] ?? <String>[],
      'cart.amount.50eg': defaultBindings['cart.amount.50eg'] ?? <String>[],
      'cart.amount.100eg': defaultBindings['cart.amount.100eg'] ?? <String>[],
      'cart.amount.200eg': defaultBindings['cart.amount.200eg'] ?? <String>[],
      'cart.amount.clear': defaultBindings['cart.amount.clear'] ?? <String>[],
      'search.clear': defaultBindings['search.clear'] ?? <String>[],
    };
    allActions.addAll(nonNavDefaults);

    // Custom bindings override per action-token.
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
          if (!_canUseCart(context)) return null;
          context.read<CheckoutBloc>().add(const ConfirmSale());
          return null;
        },
      ),
      ActivateQuickTileIntent: CallbackAction<ActivateQuickTileIntent>(
        onInvoke: (intent) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
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
          if (!_canUseCart(context)) return null;
          discountFocusTrigger?.value++;
          return null;
        },
      ),
      SetAmountPaid5EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 500));
          return null;
        },
      ),
      SetAmountPaid10EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 1000));
          return null;
        },
      ),
      SetAmountPaid20EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 2000));
          return null;
        },
      ),
      SetAmountPaid50EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 5000));
          return null;
        },
      ),
      SetAmountPaid100EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 10000));
          return null;
        },
      ),
      SetAmountPaid200EGIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
          final current =
              context.read<CheckoutBloc>().state.amountPaidPiastres ?? 0;
          context.read<CheckoutBloc>().add(SetAmountPaid(current + 20000));
          return null;
        },
      ),
      ClearAmountPaidIntent: CallbackAction(
        onInvoke: (_) {
          if (_isTyping(context)) return null;
          if (!_canUseCart(context)) return null;
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
