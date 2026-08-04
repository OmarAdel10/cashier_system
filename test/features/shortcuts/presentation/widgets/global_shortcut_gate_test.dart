import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/nav_destination.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/shortcuts/presentation/widgets/global_search_overlay.dart';
import 'package:cashier_system/features/shortcuts/presentation/widgets/global_shortcut_gate.dart';
import '../../../../features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> close() async {}
}

class _TestInventoryBloc extends InventoryBloc {
  _TestInventoryBloc({List<ProductEntity> quickTiles = const []})
      : _quickTiles = quickTiles,
        super(repository: _FakeInventoryRepo());

  final List<ProductEntity> _quickTiles;

  @override
  InventoryState get state => InventoryState(
        inventoryMap: {
          for (final p in _quickTiles) p.barcode: p,
        },
        quickTileList: _quickTiles,
        status: InventoryStatus.ready,
      );

  @override
  Stream<InventoryState> get stream => Stream.value(state);
}

class _FakeInventoryRepo implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async =>
      Right({});
  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async =>
      Right([]);
  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateTileColor(
          String barcode, String colorHex) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateStock(
          String barcode, int deltaQuantity) async =>
      const Right(null);
}

class _TrackingCheckoutBloc extends CheckoutBloc {
  final List<CheckoutEvent> receivedEvents = [];

  @override
  void onEvent(CheckoutEvent event) {
    receivedEvents.add(event);
    super.onEvent(event);
  }
}

Widget _buildTestWidget({
  required SettingsBloc settingsBloc,
  required InventoryBloc inventoryBloc,
  required CheckoutBloc checkoutBloc,
  required ValueNotifier<NavDestination> selectedDestination,
  required ValueNotifier<bool> isSearchOpenNotifier,
  required ValueNotifier<String> barcodeInjectionNotifier,
  List<NavDestination> allowedDestinations = const [NavDestination.checkout],
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
      BlocProvider<InventoryBloc>.value(value: inventoryBloc),
      BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
    ],
    child: MaterialApp(
      home: GlobalShortcutGate(
        selectedDestination: selectedDestination,
        allowedDestinations: allowedDestinations,
        isSearchOpenNotifier: isSearchOpenNotifier,
        barcodeInjectionNotifier: barcodeInjectionNotifier,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Center(
              child: Column(
                children: const [
                  Text('child-content'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late SettingsBloc settingsBloc;
  late _TestInventoryBloc inventoryBloc;
  late _TrackingCheckoutBloc checkoutBloc;
  late ValueNotifier<NavDestination> selectedDestination;
  late ValueNotifier<bool> isSearchOpenNotifier;
  late ValueNotifier<String> barcodeNotifier;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    inventoryBloc = _TestInventoryBloc();
    checkoutBloc = _TrackingCheckoutBloc();
    selectedDestination = ValueNotifier(NavDestination.checkout);
    isSearchOpenNotifier = ValueNotifier(false);
    barcodeNotifier = ValueNotifier<String>('');
    addTearDown(() {
      settingsBloc.close();
      checkoutBloc.close();
      inventoryBloc.close();
      selectedDestination.dispose();
      isSearchOpenNotifier.dispose();
      barcodeNotifier.dispose();
    });
  });

  group('GlobalShortcutGate navigation', () {
    testWidgets('F1 navigates to checkout when allowed', (tester) async {
      selectedDestination.value = NavDestination.sales;
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [
            NavDestination.checkout,
            NavDestination.sales,
          ],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();

      expect(selectedDestination.value, NavDestination.checkout);
    });

    testWidgets('F2 navigates to inventory when allowed', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [NavDestination.inventory],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(selectedDestination.value, NavDestination.inventory);
    });

    testWidgets('F3 navigates to sales when allowed', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [NavDestination.sales],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();

      expect(selectedDestination.value, NavDestination.sales);
    });

    testWidgets('F4 navigates to settings when allowed', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [NavDestination.settings],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.pump();

      expect(selectedDestination.value, NavDestination.settings);
    });

    testWidgets('navigation to disallowed destination is ignored',
        (tester) async {
      selectedDestination.value = NavDestination.checkout;
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [NavDestination.checkout],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(selectedDestination.value, NavDestination.checkout);
    });
  });

  group('GlobalShortcutGate confirm sale', () {
    testWidgets('F12 confirms sale while on checkout', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();

      expect(
        checkoutBloc.receivedEvents.any((e) => e is ConfirmSale),
        isTrue,
      );
    });

    testWidgets('F12 does not confirm sale when not on checkout',
        (tester) async {
      selectedDestination.value = NavDestination.sales;
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [
            NavDestination.checkout,
            NavDestination.sales,
          ],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();

      expect(
        checkoutBloc.receivedEvents.any((e) => e is ConfirmSale),
        isFalse,
      );
    });

    testWidgets('F12 does not confirm sale while typing in a text field',
        (tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<InventoryBloc>.value(value: inventoryBloc),
            BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          ],
          child: MaterialApp(
            home: GlobalShortcutGate(
              selectedDestination: selectedDestination,
              isSearchOpenNotifier: isSearchOpenNotifier,
              barcodeInjectionNotifier: barcodeNotifier,
              child: Scaffold(
                body: Column(
                  children: const [
                    TextField(autofocus: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();

      expect(
        checkoutBloc.receivedEvents.any((e) => e is ConfirmSale),
        isFalse,
      );
    });
  });

  group('GlobalShortcutGate quick tiles', () {
    testWidgets('alt+1 adds quick tile product while on checkout',
        (tester) async {
      inventoryBloc = _TestInventoryBloc(
        quickTiles: [
          const ProductEntity(barcode: '777', name: 'Cola', price: 10.0),
        ],
      );
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(
        checkoutBloc.receivedEvents
            .whereType<AddToCart>()
            .any((e) => e.barcode == '777'),
        isTrue,
      );
    });

    testWidgets('alt+1 is ignored when not on checkout', (tester) async {
      inventoryBloc = _TestInventoryBloc(
        quickTiles: [
          const ProductEntity(barcode: '777', name: 'Cola', price: 10.0),
        ],
      );
      selectedDestination.value = NavDestination.settings;
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
          allowedDestinations: const [
            NavDestination.checkout,
            NavDestination.settings,
          ],
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(checkoutBloc.receivedEvents.whereType<AddToCart>(), isEmpty);
    });
  });

  group('GlobalShortcutGate search overlay', () {
    testWidgets('F5 opens the search overlay', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();

      expect(find.byType(GlobalSearchOverlay), findsOneWidget);
      expect(isSearchOpenNotifier.value, isTrue);
    });

    testWidgets('F5 while overlay is open closes it (toggle)', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(GlobalSearchOverlay), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();

      expect(find.byType(GlobalSearchOverlay), findsNothing);
      expect(isSearchOpenNotifier.value, isFalse);
    });

    testWidgets('shortcuts still work after overlay closes (focus restored)',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(GlobalSearchOverlay), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();
      expect(find.byType(GlobalSearchOverlay), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();

      expect(
        checkoutBloc.receivedEvents.any((e) => e is ConfirmSale),
        isTrue,
      );
    });

    testWidgets('unknown custom binding does not crash', (tester) async {
      settingsBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            customBindings: {
              'cart.confirm': ['f12', 'ctrl+m'],
              'no.such.action': ['f9'],
            },
          ),
        ),
      );
      settingsBloc.add(const LoadSettings());
      await tester.pumpWidget(
        _buildTestWidget(
          settingsBloc: settingsBloc,
          inventoryBloc: inventoryBloc,
          checkoutBloc: checkoutBloc,
          selectedDestination: selectedDestination,
          isSearchOpenNotifier: isSearchOpenNotifier,
          barcodeInjectionNotifier: barcodeNotifier,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f9);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();
      expect(
        checkoutBloc.receivedEvents.any((e) => e is ConfirmSale),
        isTrue,
      );
    });
  });
}
