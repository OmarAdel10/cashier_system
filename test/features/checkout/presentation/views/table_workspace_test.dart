import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/views/table_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/table_session_dialog.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/inventory/helpers/fake_inventory_repository.dart';
import '../../../../features/settings/helpers/fake_settings_repository.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';
import '../../../receipts/helpers/fake_refunds_repository.dart';
import '../../helpers/fake_table_repositories.dart';
import '../../helpers/fake_zone_repository.dart';

Widget _wrap({
  required SettingsBloc settingsBloc,
  required TableBloc tableBloc,
  required ZoneBloc zoneBloc,
  required InventoryBloc inventoryBloc,
  required ReceiptsBloc receiptsBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
      BlocProvider<TableBloc>.value(value: tableBloc),
      BlocProvider<ZoneBloc>.value(value: zoneBloc),
      BlocProvider<InventoryBloc>.value(value: inventoryBloc),
      BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
    ],
    child: MaterialApp(home: Scaffold(body: const TableWorkspace())),
  );
}

/// Creates fresh SettingsBloc + ZoneBloc + InventoryBloc + ReceiptsBloc and
/// dispatches their load events. Blocs are always created inside the test
/// body: flutter_bloc event handlers await repository futures, and blocs
/// created in setUp() get parked mid-await outside the test's FakeAsync zone
/// (workspace would stay stuck in the loading state).
({
  SettingsBloc settings,
  ZoneBloc zones,
  InventoryBloc inventory,
  ReceiptsBloc receipts,
}) _freshSharedBlocs() {
  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en', businessType: 'table'),
    ),
  );
  settingsBloc.add(const LoadSettings());
  final zoneBloc = ZoneBloc(
    repository: FakeZoneRepository([
      const ZoneEntity(id: 'Z-DINE', name: 'Main Hall', kind: ZoneKind.dineIn),
      const ZoneEntity(id: 'Z-TAKE', name: 'Pickup', kind: ZoneKind.takeaway),
    ]),
  );
  zoneBloc.add(const LoadZones());
  final inventoryBloc = InventoryBloc(repository: FakeInventoryRepository());
  inventoryBloc.add(const LoadInventory());
  final receiptsBloc = ReceiptsBloc(
    receiptsRepo: FakeReceiptsRepository(),
    inventoryRepo: FakeInventoryRepository(),
    refundsRepo: FakeRefundsRepository(),
    authRepo: FakeAuthRepository(),
  );
  return (
    settings: settingsBloc,
    zones: zoneBloc,
    inventory: inventoryBloc,
    receipts: receiptsBloc,
  );
}

List<TableEntity> _fixture() => [
  const TableEntity(
    id: 'T1',
    name: 'T1',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.available,
  ),
  const TableEntity(
    id: 'R1',
    name: 'Room-1',
    zoneId: 'Z-DINE',
    capacity: 6,
    isRoom: true,
    hourlyRatePiastres: 5000,
    status: TableStatus.available,
  ),
  TableEntity(
    id: 'T-OCC',
    name: 'T-Occ',
    zoneId: 'Z-DINE',
    capacity: 2,
    status: TableStatus.occupied,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 45)),
  ),
  TableEntity(
    id: 'T-PEND',
    name: 'T-Pend',
    zoneId: 'Z-TAKE',
    capacity: 2,
    status: TableStatus.orderPending,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 20)),
  ),
  TableEntity(
    id: 'T-SRV',
    name: 'T-Srv',
    zoneId: 'Z-TAKE',
    capacity: 2,
    status: TableStatus.served,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  TableEntity(
    id: 'T-PAY',
    name: 'T-Pay',
    zoneId: 'Z-DINE',
    capacity: 8,
    status: TableStatus.paymentPending,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 10)),
  ),
];

(TableBloc, FakeTableRepository) _tableBlocWith(List<TableEntity> tables) {
  final repo = FakeTableRepository(tables);
  final bloc = TableBloc(
    tableRepository: repo,
    roundRepository: FakeRoundRepository(),
  );
  bloc.add(const LoadTables());
  return (bloc, repo);
}

/// Bounded pump sequence: card occupancy timers schedule a frame every
/// second, so pumpAndSettle would never settle. A few short pumps flush the
/// async load futures instead.
Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('renders zone sections dine-in first, takeaway last', (
    tester,
  ) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('Main Hall'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    final dineY = tester.getTopLeft(find.text('Main Hall')).dy;
    final takeY = tester.getTopLeft(find.text('Pickup')).dy;
    expect(dineY, lessThan(takeY));
  });

  testWidgets('available table shows capacity and no timer', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('T1'), findsOneWidget);
    expect(find.text('Seats 4'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is Text && w.data == 'T1'),
        matching: find.textContaining('⏱'),
      ),
      findsNothing,
    );
  });

  testWidgets('room card shows hourly rate when available', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('Room-1'), findsOneWidget);
    expect(find.textContaining('50.00'), findsWidgets);
  });

  testWidgets('occupied room card shows occupied timer and room rent', (
    tester,
  ) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, _) = _tableBlocWith([
      TableEntity(
        id: 'R-OCC',
        name: 'Room-Occ',
        zoneId: 'Z-DINE',
        capacity: 6,
        isRoom: true,
        hourlyRatePiastres: 5000,
        status: TableStatus.occupied,
        tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 75)),
      ),
    ]);
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('Room-Occ'), findsOneWidget);
    // 75 minutes -> chargedHours = 2 -> rent = 2 * 5000 = 100.00
    expect(find.textContaining('100.00'), findsOneWidget);
  });

  testWidgets('tapping available table opens the tab and the session dialog', (
    tester,
  ) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, repo) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    await tester.tap(find.text('T1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TableSessionDialog), findsOneWidget);
    expect(find.text('Session - T1'), findsOneWidget);

    final updated = repo.all.firstWhere((t) => t.id == 'T1');
    expect(updated.status, TableStatus.occupied);
    expect(updated.tabOpenedAt, isNotNull);
  });

  testWidgets('shows empty state when no tables', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final (tableBloc, _) = _tableBlocWith([]);
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('No tables yet'), findsOneWidget);
  });

  testWidgets('shows error state on load failure', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    addTearDown(shared.inventory.close);
    addTearDown(shared.receipts.close);
    final failingRepo = FakeTableRepository();
    failingRepo.failOnGet = true;
    final tableBloc = TableBloc(
      tableRepository: failingRepo,
      roundRepository: FakeRoundRepository(),
    );
    tableBloc.add(const LoadTables());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
        inventoryBloc: shared.inventory,
        receiptsBloc: shared.receipts,
      ),
    );
    await _pumpReady(tester);

    expect(find.text('Checkout Error'), findsOneWidget);
  });
}
