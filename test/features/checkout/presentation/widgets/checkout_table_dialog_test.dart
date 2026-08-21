import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_event.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_table_dialog.dart';
import '../../../../features/inventory/helpers/fake_inventory_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../auth/helpers/fake_shifts_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_table_repositories.dart';
import '../../helpers/fake_zone_repository.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';
import '../../../receipts/helpers/fake_refunds_repository.dart';

Future<void> pumpCheckout(
  WidgetTester tester,
  TableEntity table, {
  List<TableRoundEntity> rounds = const [],
  List<TableOrderLine> drafts = const [],
  AppSettingsEntity settings = const AppSettingsEntity(languageCode: 'en'),
  List<ZoneEntity> zones = const [
    ZoneEntity(id: 'Z-DINE', name: 'Main Hall', kind: ZoneKind.dineIn),
  ],
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final tableRepo = FakeTableRepository([table]);
  final roundRepo = FakeRoundRepository(rounds);
  final tableBloc = TableBloc(
    tableRepository: tableRepo,
    roundRepository: roundRepo,
  );
  addTearDown(tableBloc.close);
  tableBloc.add(const LoadTables());
  if (drafts.isNotEmpty) {
    tableBloc.add(UpdateDraftLines(table.id, drafts));
  }
  await tester.pump();

  final zoneBloc = ZoneBloc(repository: FakeZoneRepository(zones));
  addTearDown(zoneBloc.close);
  zoneBloc.add(const LoadZones());
  await tester.pump();

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(settings),
  );
  addTearDown(settingsBloc.close);
  settingsBloc.add(const LoadSettings());
  await tester.pump();

  final shiftBloc = ShiftBloc(repository: FakeShiftsRepository());
  addTearDown(shiftBloc.close);
  shiftBloc.add(const StartShift('admin'));
  await tester.pump();

  final authBloc = AuthBloc(repository: FakeAuthRepository());
  addTearDown(authBloc.close);
  authBloc.add(const CheckAuth());
  await tester.pump();

  final receiptsRepo = FakeReceiptsRepository();
  final receiptsBloc = ReceiptsBloc(
    receiptsRepo: receiptsRepo,
    inventoryRepo: FakeInventoryRepository(),
    refundsRepo: FakeRefundsRepository(),
    authRepo: FakeAuthRepository(),
    generateId: () => 'receipt-${DateTime.now().microsecondsSinceEpoch}',
  );
  addTearDown(receiptsBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<TableBloc>.value(value: tableBloc),
          BlocProvider<ZoneBloc>.value(value: zoneBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<ShiftBloc>.value(value: shiftBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
        ],
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CheckoutTableDialog(table: table),
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
}

void main() {
  final occupied = TableEntity(
    id: 'T1',
    name: 'T1',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.occupied,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 30)),
  );

  group('CheckoutTableDialog', () {
    testWidgets('shows billed lines and totals from fired and draft lines', (
      tester,
    ) async {
      await pumpCheckout(
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
                name: 'Koshary',
                barcode: 'K1',
                quantity: 2,
                unitPricePiastres: 1000,
                prepCategory: PrepCategory.food,
              ),
            ],
          ),
        ],
        drafts: const [
          TableOrderLine(
            name: 'Cola',
            barcode: 'C1',
            quantity: 2,
            unitPricePiastres: 500,
            prepCategory: PrepCategory.beverage,
          ),
        ],
      );

      expect(find.text('Koshary x2'), findsOneWidget);
      expect(find.text('Cola x2'), findsOneWidget);
      expect(find.textContaining('30.00'), findsWidgets); // total 3000
    });

    testWidgets('discount stepper updates the composed total', (tester) async {
      await pumpCheckout(
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
                name: 'Koshary',
                barcode: 'K1',
                quantity: 2,
                unitPricePiastres: 1000,
                prepCategory: PrepCategory.food,
              ),
            ],
          ),
        ],
      );

      expect(find.textContaining('20.00'), findsWidgets); // 2000 total
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('discount-stepper')),
          matching: find.byIcon(Icons.add_circle_outline),
        ),
      );
      await tester.pumpAndSettle();
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        debugPrint('TXT: ${w.data}');
      }
      expect(find.textContaining('19.80'), findsWidgets); // 2000 - 1% = 1980
    });

    testWidgets('renders room rent, service and tax lines when enabled', (
      tester,
    ) async {
      final roomTable = TableEntity(
        id: 'R1',
        name: 'VIP',
        zoneId: 'Z-DINE',
        capacity: 4,
        isRoom: true,
        hourlyRatePiastres: 1000,
        status: TableStatus.occupied,
        tabOpenedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await pumpCheckout(
        tester,
        roomTable,
        rounds: [
          TableRoundEntity(
            id: 'R2',
            tableId: 'R1',
            roundNumber: 1,
            firedAt: DateTime.now().subtract(const Duration(minutes: 10)),
            lines: const [
              TableOrderLine(
                name: 'Tea',
                barcode: 'T1',
                quantity: 1,
                unitPricePiastres: 500,
                prepCategory: PrepCategory.beverage,
              ),
            ],
          ),
        ],
        settings: const AppSettingsEntity(
          languageCode: 'en',
          taxEnabled: true,
          taxPercent: 5,
          serviceChargeEnabled: true,
          serviceChargePercent: 12,
          minChargeEnabled: true,
          minChargePerTablePiastres: 3000,
        ),
      );

      expect(find.text('Room Rent'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Minimum Charge'), findsOneWidget);
      // 500 items + 2000 room = 2500 base; floor to 3000 (+500 delta)
      // service 12% = 360; subtotal 3360; tax 5% = 168; total 3528
      expect(find.textContaining('35.28'), findsWidgets);
    });

    testWidgets('confirm issues split receipts and completes checkout', (
      tester,
    ) async {
      final tableRepo = FakeTableRepository([occupied]);
      final roundRepo = FakeRoundRepository([
        TableRoundEntity(
          id: 'R1',
          tableId: 'T1',
          roundNumber: 1,
          firedAt: DateTime.now().subtract(const Duration(minutes: 20)),
          lines: const [
            TableOrderLine(
              name: 'Koshary',
              barcode: 'K1',
              quantity: 2,
              unitPricePiastres: 1000,
              prepCategory: PrepCategory.food,
            ),
            TableOrderLine(
              name: 'Cola',
              barcode: 'C1',
              quantity: 2,
              unitPricePiastres: 500,
              prepCategory: PrepCategory.beverage,
            ),
          ],
        ),
      ]);
      final receiptsRepo = FakeReceiptsRepository();
      final tableBloc = TableBloc(
        tableRepository: tableRepo,
        roundRepository: roundRepo,
      );
      addTearDown(tableBloc.close);
      tableBloc.add(const LoadTables());
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();

      final zoneBloc = ZoneBloc(
        repository: FakeZoneRepository([
          const ZoneEntity(
            id: 'Z-DINE',
            name: 'Main Hall',
            kind: ZoneKind.dineIn,
          ),
        ]),
      );
      addTearDown(zoneBloc.close);
      zoneBloc.add(const LoadZones());
      await tester.pump();

      final settingsBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            languageCode: 'en',
            shownPaymentTypeIds: ['cash', 'card'],
          ),
        ),
      );
      addTearDown(settingsBloc.close);
      settingsBloc.add(const LoadSettings());
      await tester.pump();

      final shiftBloc = ShiftBloc(repository: FakeShiftsRepository());
      addTearDown(shiftBloc.close);
      shiftBloc.add(const StartShift('admin'));
      await tester.pump();

      final authBloc = AuthBloc(repository: FakeAuthRepository());
      addTearDown(authBloc.close);
      authBloc.add(const CheckAuth());
      await tester.pump();

      final receiptsBloc = ReceiptsBloc(
        receiptsRepo: receiptsRepo,
        inventoryRepo: FakeInventoryRepository(),
        refundsRepo: FakeRefundsRepository(),
        authRepo: FakeAuthRepository(),
        generateId: () => 'receipt-${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(receiptsBloc.close);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MultiBlocProvider(
            providers: [
              BlocProvider<TableBloc>.value(value: tableBloc),
              BlocProvider<ZoneBloc>.value(value: zoneBloc),
              BlocProvider<SettingsBloc>.value(value: settingsBloc),
              BlocProvider<ShiftBloc>.value(value: shiftBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
            ],
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CheckoutTableDialog(table: occupied),
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

      // Split into 2 receipts.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('split-stepper')),
          matching: find.byIcon(Icons.add_circle_outline),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('checkout-amount-paid')),
        '3000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout-confirm')));
      await tester.pumpAndSettle();
      // let the serialized CreateReceipts finish their async repo chain
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Dialog closed (session flow pops on success).
      expect(find.byKey(const Key('checkout-confirm')), findsNothing);

      // Two receipts, one per split part.
      final savedResult = await receiptsRepo.getAll();
      final saved = savedResult.fold((_) => <ReceiptEntity>[], (r) => r);
      expect(saved.length, 2);
      final totals = saved.map((r) => r.totalPiastres).toList()..sort();
      expect(totals, [1500, 1500]);
      expect(saved.every((r) => r.amountPaidPiastres == 1500), isTrue);
      expect(saved.every((r) => r.paymentType == 'cash'), isTrue);

      // Table reset, drafts cleared, rounds archived.
      final updatedTable = tableRepo.all.firstWhere((t) => t.id == 'T1');
      expect(updatedTable.status, TableStatus.available);
      expect(updatedTable.tabOpenedAt, isNull);
      expect(roundRepo.all.single.status, RoundStatus.archived);
    });
  });
}
