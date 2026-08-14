import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/table_session_dialog.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

import '../../../settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_table_repositories.dart';

class _FakeInventoryRepo implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async =>
      const Right({});

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

/// Pumps the session dialog for [table] inside providers. Blocs are created
/// in the test body (load handlers await repository futures, so setUp-created
/// blocs park mid-await under FakeAsync).
Future<(TableBloc, FakeTableRepository, FakeRoundRepository)> pumpSession(
  WidgetTester tester,
  TableEntity table, {
  List<TableRoundEntity> rounds = const [],
  List<ProductEntity> products = const [],
}) async {
  final tableRepo = FakeTableRepository([table]);
  final roundRepo = FakeRoundRepository(rounds);
  final tableBloc = TableBloc(
    tableRepository: tableRepo,
    roundRepository: roundRepo,
  );
  addTearDown(tableBloc.close);
  tableBloc.add(const LoadTables());

  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en', businessType: 'cafe'),
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
          BlocProvider<TableBloc>.value(value: tableBloc),
          BlocProvider<InventoryBloc>.value(value: inventoryBloc),
        ],
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TableSessionDialog(table: table),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (tableBloc, tableRepo, roundRepo);
}

void main() {
  const espresso = ProductEntity(
    barcode: 'E1',
    name: 'Espresso',
    price: 5.0,
    category: 'hot drinks',
  );
  const koshary = ProductEntity(
    barcode: 'K1',
    name: 'Koshary',
    price: 10.0,
    category: 'food',
  );
  final occupied = TableEntity(
    id: 'T1',
    name: 'T1',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.occupied,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 30)),
  );

  group('TableSessionDialog', () {
    testWidgets('shows fired round lines with quantities in the bill', (
      tester,
    ) async {
      await pumpSession(
        tester,
        occupied,
        rounds: [
          TableRoundEntity(
            id: 'R1',
            tableId: 'T1',
            roundNumber: 1,
            firedAt: DateTime.now().subtract(const Duration(minutes: 20)),
            lines: const [
              TableOrderLine(
                name: 'Espresso',
                barcode: 'E1',
                quantity: 2,
                unitPricePiastres: 500,
                prepCategory: PrepCategory.beverage,
              ),
            ],
          ),
        ],
      );

      expect(find.text('Round 1'), findsOneWidget);
      expect(find.text('Espresso x2'), findsOneWidget);
      expect(find.textContaining('10.00'), findsWidgets);
    });

    testWidgets('product tap adds a draft line, repeated tap increments qty', (
      tester,
    ) async {
      final (bloc, _, _) = await pumpSession(
        tester,
        occupied,
        products: [espresso],
      );

      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();
      var draft = bloc.state.draftFor('T1');
      expect(draft.length, 1);
      expect(draft.single.quantity, 1);
      expect(draft.single.unitPricePiastres, 500);

      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();
      draft = bloc.state.draftFor('T1');
      expect(draft.length, 1);
      expect(draft.single.quantity, 2);
    });

    testWidgets('draft minus stepper decrements and removes at zero', (
      tester,
    ) async {
      final (bloc, _, _) = await pumpSession(
        tester,
        occupied,
        products: [espresso],
      );

      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();

      final minusButton = find.byIcon(Icons.remove_circle_outline);
      expect(minusButton, findsOneWidget);
      await tester.tap(minusButton);
      await tester.pumpAndSettle();
      expect(bloc.state.draftFor('T1').single.quantity, 1);
      await tester.tap(minusButton);
      await tester.pumpAndSettle();
      expect(bloc.state.draftFor('T1'), isEmpty);
    });

    testWidgets('send order disabled while draft is empty', (tester) async {
      await pumpSession(tester, occupied, products: [espresso]);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('send-order')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();
      final enabled = tester.widget<FilledButton>(
        find.byKey(const Key('send-order')),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('send order fires round from draft and clears draft', (
      tester,
    ) async {
      final (bloc, _, roundRepo) = await pumpSession(
        tester,
        occupied,
        products: [espresso, koshary],
      );

      await tester.tap(find.text('Espresso'));
      await tester.tap(find.text('Koshary'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-order')));
      await tester.pumpAndSettle();

      expect(bloc.state.draftFor('T1'), isEmpty);
      final rounds = bloc.state.rounds.where((r) => r.tableId == 'T1');
      expect(rounds.length, 1);
      final round = rounds.single;
      expect(round.roundNumber, 1);
      expect(round.lines.length, 2);
      expect(round.lines[0].barcode, 'E1');
      expect(round.lines[1].barcode, 'K1');
      expect(roundRepo.all.length, 1);
      expect(find.text('Round 1'), findsOneWidget);
    });

    testWidgets('mark served flips round status to served', (tester) async {
      final (bloc, _, _) = await pumpSession(
        tester,
        occupied,
        rounds: [
          TableRoundEntity(
            id: 'R1',
            tableId: 'T1',
            roundNumber: 1,
            firedAt: DateTime.now().subtract(const Duration(minutes: 20)),
            lines: const [
              TableOrderLine(
                name: 'Espresso',
                barcode: 'E1',
                quantity: 1,
                unitPricePiastres: 500,
                prepCategory: PrepCategory.beverage,
              ),
            ],
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('mark-served-R1')));
      await tester.pumpAndSettle();

      final round = bloc.state.rounds.singleWhere((r) => r.id == 'R1');
      expect(round.status, RoundStatus.served);
      final table = bloc.state.tables.singleWhere((t) => t.id == 'T1');
      expect(table.status, TableStatus.served);
    });

    testWidgets('room table shows rent line in bill', (tester) async {
      final room = TableEntity(
        id: 'RM1',
        name: 'Room-1',
        zoneId: 'Z-DINE',
        capacity: 6,
        isRoom: true,
        hourlyRatePiastres: 5000,
        status: TableStatus.occupied,
        tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 75)),
      );
      await pumpSession(tester, room);

      // 75 minutes -> ceil to 2 hours -> 100.00
      expect(find.textContaining('100.00'), findsOneWidget);
    });
  });
}
