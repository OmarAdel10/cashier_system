import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_state.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/station_addon_dialog.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../helpers/fake_station_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

SettingsBloc _englishSettingsBloc() {
  final bloc = SettingsBloc(repository: FakeSettingsRepository());
  bloc.add(const LanguageToggled('en'));
  return bloc;
}

void main() {
  const ps4 = StationEntity(
    id: 'PS4-1',
    name: 'PS4-1',
    parentCategory: 'PS4',
    stationType: StationType.playstation,
    normalHourlyRate: 50,
    multiHourlyRate: 75,
    minimumGameCostNormal: 100,
    minimumGameCostMulti: 150,
    iconAsset: 'a',
    status: StationStatus.active,
  );

  const cola = ProductEntity(
    barcode: 'PROD-1',
    name: 'Cola',
    price: 15.0,
    purchasePrice: 10.0,
    stock: 20,
    isQuickTile: false,
    tileColorHex: null,
    notes: '',
    category: 'Beverages',
    prepCategory: PrepCategory.beverage,
  );

  testWidgets('adds product line, adjusts quantity and saves', (tester) async {
    final repository = FakeStationRepository([ps4]);
    final stationBloc = StationBloc(repository: repository);
    stationBloc.add(const LoadStations());
    await tester.pumpAndSettle();
    expect(stationBloc.state.status, StationBlocStatus.ready);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: _englishSettingsBloc()),
          BlocProvider<StationBloc>.value(value: stationBloc),
          BlocProvider<InventoryBloc>.value(
            value: _TestInventoryBloc(products: const [cola]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const StationAddonDialog(station: ps4),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Order F&B'), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    await tester.tap(find.text('Cola'));
    await tester.pump();
    expect(find.text('Cola ×1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('Cola ×2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(find.text('Cola ×1'), findsOneWidget);
    await tester.tap(find.text('Save Order'));
    await tester.pumpAndSettle();

    final station = stationBloc.state.stations.first;
    expect(station.addonLines, [
      TableOrderLine(
        name: 'Cola',
        barcode: 'PROD-1',
        quantity: 1,
        unitPricePiastres: 1500,
        prepCategory: PrepCategory.beverage,
      ),
    ]);
    expect(repository.all.first.addonLines, hasLength(1));
  });
}

class _TestInventoryBloc extends InventoryBloc {
  _TestInventoryBloc({List<ProductEntity> products = const []})
    : _products = products,
      super(repository: _FakeInventoryRepo());

  final List<ProductEntity> _products;

  @override
  InventoryState get state => InventoryState(
    inventoryMap: {for (final p in _products) p.barcode: p},
    quickTileList: const [],
    status: InventoryStatus.ready,
  );

  @override
  Stream<InventoryState> get stream => Stream.value(state);
}

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
    int adjustment,
  ) async => const Right(null);
}
