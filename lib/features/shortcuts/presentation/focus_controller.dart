import 'package:flutter/widgets.dart';

import '../../auth/domain/entities/nav_destination.dart';

/// Logical keyboard zone tracked by [FocusController].
///
/// Independent of Flutter's actual focus node — a zone answers
/// "what is the user operating on right now?" so a single key
/// dispatcher (GlobalShortcutGate) can route keys to the right
/// action without moving real focus for non-text shortcuts.
enum FocusZone { scanner, cart, discount, grid, dialog, none }

/// Policy layer that arbitrates where keyboard shortcuts apply.
///
/// Sits on top of Flutter's focus system — never replaces it.
/// Widgets consult [canActivate] before dispatching a shortcut.
/// Real focus moves only happen for text-entry handoffs
/// ([requestFocusLoan] + [returnToScanner]).
///
/// Tracks three pieces of state:
///   - the current [FocusZone] (logical whiteboard)
///   - the current destination (synced from GlobalShortcutGate)
///   - the modal stack depth (routes via [NavigatorObserver],
///     overlays via [pushModal]/[popModal])
///
/// Implements [NavigatorObserver] so it can be wired directly into
/// MaterialApp.navigatorObservers — no extra plumbing.
class FocusController extends NavigatorObserver {
  FocusController();

  final ValueNotifier<FocusZone> zone = ValueNotifier(FocusZone.none);

  NavDestination? _destination;
  ValueNotifier<NavDestination>? _destinationNotifier;
  bool _scannerMode = false;
  FocusNode? _scannerNode;
  FocusNode? _gridNode;
  int _routeDepth = 0;
  int _overlayDepth = 0;
  List<NavDestination> _allowedDestinations = const [];

  /// Current destination (or null before attach).
  NavDestination? get destination => _destination;

  /// Synced from GlobalShortcutGate. On change, zones no longer
  /// valid for the new destination are cleared to [FocusZone.none]
  /// (or [FocusZone.scanner] when returning to checkout with
  /// scanner mode).
  void attachDestination(ValueNotifier<NavDestination> notifier) {
    _destinationNotifier?.removeListener(_onDestinationChanged);
    _destinationNotifier = notifier;
    notifier.addListener(_onDestinationChanged);
    _destination = notifier.value;
    _resetZoneIfInvalid();
  }

  /// Whether the scanner node is logically active. False in grid
  /// mode (cart grid layout) — matches BarcodeScannerGate's
  /// existing `enabled` flag.
  void attachScannerMode(bool enabled) {
    _scannerMode = enabled;
    _resetZoneIfInvalid();
  }

  /// Nav rail for the current role. Used by
  /// [effectiveNavDefaults] to map positions → F-keys.
  void attachAllowedDestinations(List<NavDestination> rail) {
    _allowedDestinations = rail;
  }

  /// Scanner FocusNode (created by GlobalShortcutGate, passed
  /// down to BarcodeScannerGate). Held here so the keeper can
  /// reclaim it.
  void attachScannerNode(FocusNode node) {
    _scannerNode = node;
  }

  /// Grid FocusNode (owned by TableWorkspace/StationWorkspace).
  /// Reclaim target when scanner mode is off — mirrors
  /// [attachScannerNode].
  void attachGridNode(FocusNode node) {
    _gridNode = node;
  }

  /// True iff [z] is valid in the current destination with the
  /// current modal-stack depth. The single policy gate used by
  /// GlobalShortcutGate's action handlers.
  bool canActivate(FocusZone z) {
    if (_modalStackDepth > 0) return false;
    final d = _destination;
    if (d == null) return false;
    switch (z) {
      case FocusZone.scanner:
        return _scannerMode && d == NavDestination.checkout;
      case FocusZone.cart:
      case FocusZone.discount:
        return d == NavDestination.checkout;
      case FocusZone.grid:
        return !_scannerMode && d == NavDestination.checkout;
      case FocusZone.dialog:
        return true;
      case FocusZone.none:
        return false;
    }
  }

  /// Override the current zone (rare — usually the gate sets it
  /// implicitly when it dispatches a zone-gated action). Cleared
  /// automatically on destination change.
  void setZone(FocusZone z) {
    zone.value = z;
  }

  /// Routes + overlays combined.
  int get modalStackDepth => _modalStackDepth;

  int get _modalStackDepth => _routeDepth + _overlayDepth;

  /// Effective F-key bindings for the current role's nav rail:
  /// F1 → first destination, F2 → second, F3 → third. Positions
  /// past the rail length are absent (no F4 — no role has 4).
  Map<NavDestination, List<String>> get effectiveNavDefaults {
    final rail = _allowedDestinations;
    if (rail.isEmpty) return const {};
    const fKeys = ['f1', 'f2', 'f3'];
    final result = <NavDestination, List<String>>{};
    for (var i = 0; i < rail.length && i < fKeys.length; i++) {
      result[rail[i]] = [fKeys[i]];
    }
    return result;
  }

  // ── modal stack (overlays) ─────────────────────────────────────

  void pushModal() => _overlayDepth++;
  void popModal() {
    if (_overlayDepth > 0) _overlayDepth--;
  }

  // ── modal stack (routes) ───────────────────────────────────────

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routeDepth++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_routeDepth > 0) _routeDepth--;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_routeDepth > 0) _routeDepth--;
  }

  // ── focus loans ────────────────────────────────────────────────

  /// Real-focus handoff for text entry. Updates zone and focuses
  /// the target node. Caller is responsible for calling
  /// [returnToScanner] on commit/cancel.
  void requestFocusLoan(FocusZone z, FocusNode target) {
    zone.value = z;
    if (target.canRequestFocus) target.requestFocus();
  }

  /// Explicit return path. No-ops while a modal is open or while
  /// another node already holds focus (nothing to reclaim).
  void returnToScanner() {
    if (!canReclaimScanner()) return;
    zone.value = FocusZone.scanner;
    final node = _scannerNode!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.hasFocus && node.canRequestFocus) node.requestFocus();
    });
  }

  /// Called by the FocusManager watcher on primaryFocus == null.
  /// Mode-aware: scanner mode → scanner node, grid mode → grid node.
  bool reclaimOnPrimaryFocusNull() {
    if (_scannerMode) return reclaimScannerOnPrimaryFocusNull();
    return reclaimGridOnPrimaryFocusNull();
  }

  /// Called by the FocusManager watcher on primaryFocus == null.
  /// Kept separate so tests can drive the pure logic without a
  /// real FocusManager.
  bool reclaimScannerOnPrimaryFocusNull() {
    if (!canReclaimScanner()) return false;
    zone.value = FocusZone.scanner;
    final node = _scannerNode!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.hasFocus && node.canRequestFocus) node.requestFocus();
    });
    return true;
  }

  /// Grid-mode counterpart of [reclaimScannerOnPrimaryFocusNull].
  bool reclaimGridOnPrimaryFocusNull() {
    if (!canReclaimGrid()) return false;
    zone.value = FocusZone.grid;
    final node = _gridNode!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.hasFocus && node.canRequestFocus) node.requestFocus();
    });
    return true;
  }

  /// Pure predicate (testable without a FocusManager).
  bool canReclaimScanner() {
    if (_modalStackDepth > 0) return false;
    final node = _scannerNode;
    if (node == null) return false;
    if (!_scannerMode) return false;
    if (_destination != NavDestination.checkout) return false;
    if (!node.canRequestFocus) return false;
    if (node.hasFocus) return false;
    return true;
  }

  /// Grid-mode counterpart of [canReclaimScanner].
  bool canReclaimGrid() {
    if (_modalStackDepth > 0) return false;
    final node = _gridNode;
    if (node == null) return false;
    if (_scannerMode) return false;
    if (_destination != NavDestination.checkout) return false;
    if (!node.canRequestFocus) return false;
    if (node.hasFocus) return false;
    return true;
  }

  // ── internal ───────────────────────────────────────────────────

  void _onDestinationChanged() {
    final n = _destinationNotifier;
    if (n == null) return;
    _destination = n.value;
    _resetZoneIfInvalid();
  }

  void _resetZoneIfInvalid() {
    final z = zone.value;
    if (z == FocusZone.none || z == FocusZone.dialog) return;
    if (!canActivate(z)) {
      zone.value = _scannerMode && _destination == NavDestination.checkout
          ? FocusZone.scanner
          : FocusZone.none;
    }
  }

  void dispose() {
    _destinationNotifier?.removeListener(_onDestinationChanged);
    zone.dispose();
  }
}
