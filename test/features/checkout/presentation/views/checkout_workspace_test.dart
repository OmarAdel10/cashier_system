import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/cart_item_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/views/checkout_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/product_category_grid.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../../features/settings/helpers/fake_settings_repository.dart';

class _FakeInventoryRepo implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async =>
      const Right({});
  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async =>
      const Right([]);
  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateTileColor(
    String barcode,
    String colorHex,
  ) async => const Right(null);
  @override
  Future<Either<Failure, void>> updateStock(
    String barcode,
    int deltaQuantity,
  ) async => const Right(null);
}

class _TestInventoryBloc extends InventoryBloc {
  _TestInventoryBloc({List<ProductEntity> products = const []})
    : _products = products,
      super(repository: _FakeInventoryRepo());

  final List<ProductEntity> _products;

  @override
  InventoryState get state => InventoryState(
    inventoryMap: {for (final p in _products) p.barcode: p},
    quickTileList: _products.where((p) => p.isQuickTile).toList(),
    status: InventoryStatus.ready,
  );

  @override
  Stream<InventoryState> get stream => Stream.value(state);
}

void main() {
  const espresso = ProductEntity(
    barcode: 'E1',
    name: 'Espresso',
    price: 5.0,
    category: 'hot drinks',
    isQuickTile: true,
  );

  Future<CheckoutBloc> pumpWorkspace(
    WidgetTester tester,
    String businessType, {
    List<ProductEntity> products = const [],
    bool favoritesToggle = false,
  }) async {
    final checkoutBloc = CheckoutBloc();
    addTearDown(checkoutBloc.close);
    final settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity()
            .copyWith(businessType: businessType, languageCode: 'en')
            .copyWith(favoritesStripEnabled: favoritesToggle),
      ),
    );
    addTearDown(settingsBloc.close);
    settingsBloc.add(const LoadSettings());
    final inventoryBloc = _TestInventoryBloc(products: products);
    addTearDown(inventoryBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<InventoryBloc>.value(value: inventoryBloc),
            BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
          ],
          child: child!,
        ),
        home: const Scaffold(body: CheckoutWorkspace()),
      ),
    );
    await tester.pumpAndSettle();
    return checkoutBloc;
  }

  Finder gridProduct(String name) => find.descendant(
    of: find.byType(ProductCategoryGrid),
    matching: find.text(name),
  );

  testWidgets(
    'grid mode cafe shows cart SectionCard and grid, no quick tiles or empty state',
    (tester) async {
      await pumpWorkspace(tester, 'cafe', products: [espresso]);

      expect(find.byType(ProductCategoryGrid), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);
      expect(find.text('Quick Items'), findsNothing);
      expect(find.text('Nothing here yet'), findsNothing);
    },
  );

  testWidgets('retail keeps today layout with empty state and quick tiles', (
    tester,
  ) async {
    await pumpWorkspace(tester, 'retail');

    expect(find.byType(ProductCategoryGrid), findsNothing);
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Scan a barcode or tap a quick tile'), findsOneWidget);
  });

  testWidgets(
    'cafe mode tapping a product dispatches AddToCart with product details',
    (tester) async {
      final checkoutBloc = await pumpWorkspace(
        tester,
        'cafe',
        products: [espresso],
      );

      await tester.tap(gridProduct('Espresso'));
      await tester.pumpAndSettle();

      final items = checkoutBloc.state.cart?.items ?? <CartItemEntity>[];
      expect(items.length, 1);
      expect(items.first.barcode, 'E1');
      expect(items.first.unitPricePiastres, 500);
      expect(items.first.quantity, 1);
    },
  );

  testWidgets('tapping same product again increments cart quantity', (
    tester,
  ) async {
    final checkoutBloc = await pumpWorkspace(
      tester,
      'cafe',
      products: [espresso],
    );

    await tester.tap(gridProduct('Espresso'));
    await tester.pumpAndSettle();
    await tester.tap(gridProduct('Espresso'));
    await tester.pumpAndSettle();

    final items = checkoutBloc.state.cart?.items ?? <CartItemEntity>[];
    expect(items.length, 1);
    expect(items.first.quantity, 2);
  });
}
