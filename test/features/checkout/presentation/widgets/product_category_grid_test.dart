import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
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
      Right({});
  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateProduct(
    String oldBarcode,
    ProductEntity product,
  ) async => const Right(null);
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
  );
  const americano = ProductEntity(
    barcode: 'E2',
    name: 'Americano',
    price: 5.0,
    category: 'hot drinks',
  );
  const mocha = ProductEntity(
    barcode: 'E3',
    name: 'Hot Chocolate',
    price: 5.0,
    category: 'hot drinks',
  );
  const orangeJuice = ProductEntity(
    barcode: 'J1',
    name: 'Orange Juice',
    price: 5.0,
    category: 'juices',
  );
  const cocaCola = ProductEntity(
    barcode: 'S1',
    name: 'Coca Cola',
    price: 5.0,
    category: 'soda',
  );

  final hotDrinkProducts = [espresso, americano, mocha];
  final cafeProducts = [...hotDrinkProducts, orangeJuice, cocaCola];

  late SettingsBloc settingsBloc;
  late _TestInventoryBloc inventoryBloc;

  setUp(() {
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(languageCode: 'en'),
      ),
    );
    settingsBloc.add(const LoadSettings());
    addTearDown(settingsBloc.close);
  });

  Widget buildGrid({
    required BusinessType businessType,
    required List<ProductEntity> products,
    ValueChanged<ProductEntity>? onProductTap,
  }) {
    inventoryBloc = _TestInventoryBloc(products: products);
    addTearDown(inventoryBloc.close);
    final gridFocus = FocusNode();
    addTearDown(gridFocus.dispose);
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<InventoryBloc>.value(value: inventoryBloc),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProductCategoryGrid(
            businessType: businessType,
            gridFocus: gridFocus,
            onProductTap: onProductTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> pumpWithSize(
    WidgetTester tester,
    Widget widget, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
  }

  testWidgets('cafe: 6 category chips rendered', (tester) async {
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: cafeProducts),
      size: const Size(1000, 600),
    );
    // All + hot drinks + cold drinks + soda + juices + desserts
    expect(find.text('All'), findsOneWidget);
    expect(find.text('hot drinks'), findsOneWidget);
    expect(find.text('cold drinks'), findsOneWidget);
    expect(find.text('soda'), findsOneWidget);
    expect(find.text('juices'), findsOneWidget);
    expect(find.text('desserts'), findsOneWidget);
  });

  testWidgets('cafe: selecting hot drinks filters grid to that category', (
    tester,
  ) async {
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: cafeProducts),
      size: const Size(1000, 600),
    );
    await tester.tap(find.text('hot drinks'));
    await tester.pumpAndSettle();
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('Hot Chocolate'), findsOneWidget);
    expect(find.text('Orange Juice'), findsNothing);
    expect(find.text('Coca Cola'), findsNothing);
  });

  testWidgets('search filters across current category', (tester) async {
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: cafeProducts),
      size: const Size(1000, 600),
    );
    await tester.enterText(find.byType(TextField), 'co');
    await tester.pumpAndSettle();
    expect(find.text('Hot Chocolate'), findsOneWidget);
    expect(find.text('Coca Cola'), findsOneWidget);
    expect(find.text('Espresso'), findsNothing);
    expect(find.text('Orange Juice'), findsNothing);
  });

  testWidgets('narrow surface shows horizontal chip row instead of rail', (
    tester,
  ) async {
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: cafeProducts),
      size: const Size(600, 800),
    );
    expect(find.byKey(const ValueKey('product-grid.rail')), findsNothing);
    expect(find.byKey(const ValueKey('product-grid.chip-row')), findsOneWidget);
  });

  testWidgets('wide surface shows left rail column of chips', (tester) async {
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: cafeProducts),
      size: const Size(1000, 600),
    );
    expect(find.byKey(const ValueKey('product-grid.rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-grid.chip-row')), findsNothing);
  });

  testWidgets('favorites strip absent when favoritesStripEnabled is false', (
    tester,
  ) async {
    final fav = espresso.copyWith(isQuickTile: true);
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: [fav, americano]),
      size: const Size(1000, 600),
    );
    expect(find.byKey(const ValueKey('favorites-strip')), findsNothing);
  });

  testWidgets('favorites strip present when favoritesStripEnabled is true', (
    tester,
  ) async {
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(
          languageCode: 'en',
          favoritesStripEnabled: true,
        ),
      ),
    );
    settingsBloc.add(const LoadSettings());
    addTearDown(settingsBloc.close);
    final fav = espresso.copyWith(isQuickTile: true);
    await pumpWithSize(
      tester,
      buildGrid(businessType: BusinessType.cafe, products: [fav, americano]),
      size: const Size(1000, 600),
    );
    expect(find.byKey(const ValueKey('favorites-strip')), findsOneWidget);
    expect(find.text('Espresso'), findsNWidgets(2));
  });
}
