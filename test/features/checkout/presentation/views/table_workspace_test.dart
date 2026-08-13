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
import 'package:cashier_system/features/checkout/presentation/widgets/start_tab_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_table_repositories.dart';
import '../../helpers/fake_zone_repository.dart';

Widget _wrap({
  required SettingsBloc settingsBloc,
  required TableBloc tableBloc,
  required ZoneBloc zoneBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
      BlocProvider<TableBloc>.value(value: tableBloc),
      BlocProvider<ZoneBloc>.value(value: zoneBloc),
    ],
    child: MaterialApp(home: Scaffold(body: const TableWorkspace())),
  );
}

/// Creates fresh SettingsBloc + ZoneBloc and dispatches their load events.
/// Blocs are always created inside the test body: flutter_bloc event
/// handlers await repository futures, and blocs created in setUp() get
/// parked mid-await outside the test's FakeAsync zone (workspace would
/// stay stuck in the loading state).
({SettingsBloc settings, ZoneBloc zones}) _freshSharedBlocs() {
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
  return (settings: settingsBloc, zones: zoneBloc);
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

void main() {
  testWidgets('renders zone sections dine-in first, takeaway last', (
    tester,
  ) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

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
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

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
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Room-1'), findsOneWidget);
    expect(find.textContaining('50.00'), findsWidgets);
  });

  testWidgets('occupied room card shows occupied timer and room rent', (
    tester,
  ) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Room-Occ'), findsOneWidget);
    // 75 minutes -> chargedHours = 2 -> rent = 2 * 5000 = 100.00
    expect(find.textContaining('100.00'), findsOneWidget);
  });

  testWidgets('tapping available table opens StartTabDialog', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    final (tableBloc, _) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('T1'));
    await tester.pumpAndSettle();

    expect(find.byType(StartTabDialog), findsOneWidget);
    expect(find.text('Start Tab - T1'), findsOneWidget);
  });

  testWidgets('confirming StartTabDialog opens the tab', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    final (tableBloc, repo) = _tableBlocWith(_fixture());
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('T1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(StartTabDialog), findsNothing);
    final updated = repo.all.firstWhere((t) => t.id == 'T1');
    expect(updated.status, TableStatus.occupied);
    expect(updated.tabOpenedAt, isNotNull);
  });

  testWidgets('shows empty state when no tables', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
    final (tableBloc, _) = _tableBlocWith([]);
    addTearDown(tableBloc.close);

    await tester.pumpWidget(
      _wrap(
        settingsBloc: shared.settings,
        tableBloc: tableBloc,
        zoneBloc: shared.zones,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tables yet'), findsOneWidget);
  });

  testWidgets('shows error state on load failure', (tester) async {
    final shared = _freshSharedBlocs();
    addTearDown(shared.settings.close);
    addTearDown(shared.zones.close);
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checkout Error'), findsOneWidget);
  });
}
