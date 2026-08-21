import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/transfer_merge_dialogs.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

import '../../../settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_table_repositories.dart';

Future<(TableBloc, FakeTableRepository, FakeRoundRepository)>
pumpTransferDialog(
  WidgetTester tester,
  TableEntity sourceTable, {
  List<TableEntity> allTables = const [],
  List<TableRoundEntity> rounds = const [],
}) async {
  final tableRepo = FakeTableRepository([sourceTable, ...allTables]);
  final roundRepo = FakeRoundRepository(rounds);
  final tableBloc = TableBloc(
    tableRepository: tableRepo,
    roundRepository: roundRepo,
  );
  addTearDown(tableBloc.close);
  tableBloc.add(const LoadTables());

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en'),
    ),
  );
  addTearDown(settingsBloc.close);
  settingsBloc.add(const LoadSettings());

  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<TableBloc>.value(value: tableBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TransferTableDialog(sourceTable: sourceTable),
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

Future<(TableBloc, FakeTableRepository, FakeRoundRepository)> pumpMergeDialog(
  WidgetTester tester,
  TableEntity sourceTable, {
  List<TableEntity> allTables = const [],
  List<TableRoundEntity> rounds = const [],
}) async {
  final tableRepo = FakeTableRepository([sourceTable, ...allTables]);
  final roundRepo = FakeRoundRepository(rounds);
  final tableBloc = TableBloc(
    tableRepository: tableRepo,
    roundRepository: roundRepo,
  );
  addTearDown(tableBloc.close);
  tableBloc.add(const LoadTables());

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en'),
    ),
  );
  addTearDown(settingsBloc.close);
  settingsBloc.add(const LoadSettings());

  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<TableBloc>.value(value: tableBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => MergeTablesDialog(sourceTable: sourceTable),
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
  final occupied = TableEntity(
    id: 'T1',
    name: 'T1',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.occupied,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 30)),
  );
  final available = TableEntity(
    id: 'T2',
    name: 'T2',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.available,
  );
  final occupied2 = TableEntity(
    id: 'T3',
    name: 'T3',
    zoneId: 'Z-DINE',
    capacity: 4,
    status: TableStatus.occupied,
    tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 15)),
  );

  group('TransferTableDialog', () {
    testWidgets('shows available target tables in dropdown', (tester) async {
      await pumpTransferDialog(tester, occupied, allTables: [available]);

      expect(find.text('Transfer from: T1'), findsOneWidget);
      expect(find.byKey(const Key('transfer-target-dropdown')), findsOneWidget);
      await tester.tap(find.byKey(const Key('transfer-target-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('T2'), findsOneWidget);
    });

    testWidgets('confirm button disabled when no target selected', (
      tester,
    ) async {
      await pumpTransferDialog(tester, occupied, allTables: [available]);

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('transfer-confirm')),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets('confirm emits TransferTable event and closes dialog', (
      tester,
    ) async {
      final (bloc, _, _) = await pumpTransferDialog(
        tester,
        occupied,
        allTables: [available],
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

      await tester.tap(find.byKey(const Key('transfer-target-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2').last);
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('transfer-confirm')),
      );
      expect(confirmButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('transfer-confirm')));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byKey(const Key('transfer-confirm')), findsNothing);

      // Source table should be available
      final sourceTable = bloc.state.tables.singleWhere((t) => t.id == 'T1');
      expect(sourceTable.status, TableStatus.available);
      expect(sourceTable.tabOpenedAt, isNull);

      // Target table should be occupied with source's status
      final targetTable = bloc.state.tables.singleWhere((t) => t.id == 'T2');
      expect(targetTable.status, TableStatus.occupied);
      expect(targetTable.tabOpenedAt, isNotNull);

      // Round should be moved to target table
      final round = bloc.state.rounds.singleWhere((r) => r.id == 'R1');
      expect(round.tableId, 'T2');
    });

    testWidgets('shows no targets message when no available tables', (
      tester,
    ) async {
      await pumpTransferDialog(tester, occupied, allTables: []);

      expect(find.text('No available tables to transfer to'), findsOneWidget);
    });
  });

  group('MergeTablesDialog', () {
    testWidgets('shows occupied target tables in dropdown', (tester) async {
      await pumpMergeDialog(tester, occupied, allTables: [occupied2]);

      expect(find.text('Merge from: T1'), findsOneWidget);
      expect(find.byKey(const Key('merge-target-dropdown')), findsOneWidget);
      await tester.tap(find.byKey(const Key('merge-target-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('T3'), findsOneWidget);
    });

    testWidgets('confirm button disabled when no target selected', (
      tester,
    ) async {
      await pumpMergeDialog(tester, occupied, allTables: [occupied2]);

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('merge-confirm')),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets('confirm emits MergeTables event and closes dialog', (
      tester,
    ) async {
      final (bloc, _, _) = await pumpMergeDialog(
        tester,
        occupied,
        allTables: [occupied2],
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

      await tester.tap(find.byKey(const Key('merge-target-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T3').last);
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const Key('merge-confirm')),
      );
      expect(confirmButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('merge-confirm')));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byKey(const Key('merge-confirm')), findsNothing);

      // Source table should be available
      final sourceTable = bloc.state.tables.singleWhere((t) => t.id == 'T1');
      expect(sourceTable.status, TableStatus.available);
      expect(sourceTable.tabOpenedAt, isNull);

      // Target table should remain occupied
      final targetTable = bloc.state.tables.singleWhere((t) => t.id == 'T3');
      expect(targetTable.status, TableStatus.occupied);

      // Round should be moved to target table with renumbered round number
      final round = bloc.state.rounds.singleWhere((r) => r.id == 'R1');
      expect(round.tableId, 'T3');
      // Round should be renumbered (target had no rounds, so this becomes round 1)
      expect(round.roundNumber, 1);

      // Draft lines should NOT include fired lines from source
      // Only draft lines are merged (source had no draft, target had no draft)
      final draft = bloc.state.draftFor('T3');
      expect(draft, isEmpty);
    });

    testWidgets('shows no targets message when no occupied tables', (
      tester,
    ) async {
      await pumpMergeDialog(tester, occupied, allTables: [available]);

      expect(find.text('No occupied tables to merge into'), findsOneWidget);
    });
  });
}
