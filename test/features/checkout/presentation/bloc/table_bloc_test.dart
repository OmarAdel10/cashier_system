import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/ticket_routing.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_state.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import '../../helpers/fake_table_repositories.dart';

void main() {
  late FakeTableRepository tableRepo;
  late FakeRoundRepository roundRepo;
  late TableBloc bloc;
  late DateTime now;

  const t1 = TableEntity(id: 't1', name: 'T1', capacity: 4);
  const t2 = TableEntity(id: 't2', name: 'T2', capacity: 4);

  const drink = TableOrderLine(
    name: 'Cola',
    quantity: 2,
    unitPricePiastres: 1500,
  );

  setUp(() {
    now = DateTime(2026, 8, 9, 14, 0);
    tableRepo = FakeTableRepository([t1, t2]);
    roundRepo = FakeRoundRepository();
    bloc = TableBloc(
      tableRepository: tableRepo,
      roundRepository: roundRepo,
      now: () => now,
    );
  });

  tearDown(() {
    bloc.close();
  });

  Future<void> openTab(String id) async {
    bloc.add(OpenTab(id));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> pumpLoad() async {
    bloc.add(const LoadTables());
    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<TablesState>((s) => s.status == TablesStatus.loading),
        predicate<TablesState>(
          (s) => s.status == TablesStatus.ready && s.tables.length == 2,
        ),
      ]),
    );
  }

  group('initial state', () {
    test('should be initial with empty tables', () {
      expect(bloc.state.status, TablesStatus.initial);
      expect(bloc.state.tables, isEmpty);
      expect(bloc.state.failure, isNull);
    });
  });

  group('LoadTables', () {
    test('loads tables and rounds', () async {
      await pumpLoad();

      expect(bloc.state.tables.map((t) => t.name).toList(), ['T1', 'T2']);
    });

    test('emits error when table repo fails', () async {
      tableRepo.failOnGet = true;
      bloc.add(const LoadTables());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<TablesState>((s) => s.status == TablesStatus.loading),
          predicate<TablesState>(
            (s) => s.status == TablesStatus.error && s.failure != null,
          ),
        ]),
      );
    });
  });

  group('SaveTable / DeleteTable', () {
    test('saves a table', () async {
      await pumpLoad();
      bloc.add(const SaveTable(TableEntity(id: 't9', name: 'T9')));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tables.map((t) => t.id), contains('t9'));
    });

    test('deletes an available table', () async {
      await pumpLoad();
      bloc.add(const DeleteTable('t2'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.tables.map((t) => t.id), ['t1']);
    });

    test('rejects deleting an occupied table', () async {
      await pumpLoad();
      await openTab('t1');

      bloc.add(const DeleteTable('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.failure, isNotNull);
      expect(bloc.state.tables.map((t) => t.id), contains('t1'));
    });
  });

  group('OpenTab', () {
    test('opens a tab on an available table', () async {
      await pumpLoad();
      bloc.add(const OpenTab('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.occupied);
      expect(table.tabOpenedAt, now);
    });

    test('rejects opening a tab on an occupied table', () async {
      await pumpLoad();
      await openTab('t1');

      bloc.add(const OpenTab('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.failure, isNotNull);
    });
  });

  group('FireRound', () {
    test(
      'routes and prints kitchen/bar/shisha tickets when configured',
      () async {
        final printed = <List<TicketRoute>>[];
        final settings = AppSettingsEntity(
          businessType: 'cafe',
          kitchenTicketsEnabled: true,
          kitchenPrinterName: 'KPTR',
          barTicketsEnabled: true,
          barPrinterName: 'BPTR',
          shishaTicketsEnabled: true,
          shishaPrinterName: 'SPTR',
        );
        bloc = TableBloc(
          tableRepository: tableRepo,
          roundRepository: roundRepo,
          now: () => now,
          ticketPrinter: (round, table, routes) async => printed.add(routes),
          settingsReader: () => settings,
        );
        await pumpLoad();
        await openTab('t1');
        const food = TableOrderLine(
          name: 'Koshary',
          quantity: 1,
          unitPricePiastres: 1000,
          prepCategory: PrepCategory.food,
        );
        const drink2 = TableOrderLine(
          name: 'Cola',
          quantity: 2,
          unitPricePiastres: 1500,
          prepCategory: PrepCategory.beverage,
        );
        bloc.add(const UpdateDraftLines('t1', [food, drink2]));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const FireRound('t1'));
        await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
        await Future<void>.delayed(Duration.zero);

        expect(printed.length, 1);
        final routes = printed.single;
        expect(routes.length, 2);
        final kitchen = routes.singleWhere((r) => r.printerName == 'KPTR');
        expect(kitchen.lines.single.barcode, food.barcode);
        final bar = routes.singleWhere((r) => r.printerName == 'BPTR');
        expect(bar.lines.single.quantity, 2);
      },
    );

    test('skips printing when no ticket printer is configured', () async {
      var printCalls = 0;
      bloc = TableBloc(
        tableRepository: tableRepo,
        roundRepository: roundRepo,
        now: () => now,
        ticketPrinter: (round, table, routes) async => printCalls++,
        settingsReader: () => const AppSettingsEntity(businessType: 'cafe'),
      );
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(printCalls, 0);
      expect(bloc.state.rounds.length, 1);
    });

    test('printing failure does not fail the round', () async {
      bloc = TableBloc(
        tableRepository: tableRepo,
        roundRepository: roundRepo,
        now: () => now,
        ticketPrinter: (round, table, routes) async =>
            throw Exception('printer offline'),
        settingsReader: () => const AppSettingsEntity(
          businessType: 'cafe',
          kitchenTicketsEnabled: true,
          kitchenPrinterName: 'KPTR',
        ),
      );
      await pumpLoad();
      await openTab('t1');
      const food = TableOrderLine(
        name: 'Koshary',
        quantity: 1,
        unitPricePiastres: 1000,
        prepCategory: PrepCategory.food,
      );
      bloc.add(const UpdateDraftLines('t1', [food]));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.rounds.length, 1);
      expect(bloc.state.failure, isNull);
    });

    test('fires a round and marks table orderPending', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);

      now = DateTime(2026, 8, 9, 14, 30);
      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.orderPending);
      expect(table.activeRoundNumber, 1);
      expect(bloc.state.rounds.length, 1);
      final round = bloc.state.rounds.single;
      expect(round.roundNumber, 1);
      expect(round.lines.length, 1);
      expect(round.firedAt, now);
      expect(bloc.state.draftFor('t1'), isEmpty);
    });

    test('increments round number on second fire', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);

      now = DateTime(2026, 8, 9, 14, 30);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);

      now = DateTime(2026, 8, 9, 15, 0);
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.activeRoundNumber, 2);
      expect(bloc.state.rounds.length, 2);
      expect(bloc.state.rounds.last.roundNumber, 2);
    });

    test('rejects firing without an open tab', () async {
      await pumpLoad();
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.failure, isNotNull);
      expect(bloc.state.rounds, isEmpty);
    });

    test('rejects firing an empty round', () async {
      await pumpLoad();
      await openTab('t1');

      bloc.add(const FireRound('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.failure, isNotNull);
      expect(bloc.state.rounds, isEmpty);
    });
  });

  group('MarkServed', () {
    test('marks round served and table served', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);
      final roundId = bloc.state.rounds.single.id;

      bloc.add(MarkServed('t1', roundId));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.rounds.single.status.name, 'served');
      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.served);
    });
  });

  group('StartCheckout / CompleteCheckout', () {
    test('start checkout moves table to paymentPending', () async {
      await pumpLoad();
      await openTab('t1');

      bloc.add(const StartCheckout('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.paymentPending);
    });

    test('complete checkout resets table and drafts', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const StartCheckout('t1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CompleteCheckout('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.available);
      expect(table.tabOpenedAt, isNull);
      expect(table.activeRoundNumber, isNull);
      expect(bloc.state.draftFor('t1'), isEmpty);
    });

    test('complete checkout archives the table rounds', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const StartCheckout('t1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CompleteCheckout('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.rounds, isEmpty);
      expect(roundRepo.all.single.status, RoundStatus.archived);
    });
  });

  group('TransferTable', () {
    test('moves tab and rounds to target', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const TransferTable('t1', 't2'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final source = bloc.state.tables.firstWhere((t) => t.id == 't1');
      final target = bloc.state.tables.firstWhere((t) => t.id == 't2');
      expect(source.status, TableStatus.available);
      expect(source.tabOpenedAt, isNull);
      // Tab status is carried over to the target with the tab.
      expect(target.status, TableStatus.orderPending);
      expect(target.tabOpenedAt, now);
      expect(bloc.state.rounds.single.tableId, 't2');
      expect(roundRepo.all.single.tableId, 't2');
    });

    test('rejects transfer to an occupied target', () async {
      await pumpLoad();
      await openTab('t1');
      await openTab('t2');

      bloc.add(const TransferTable('t1', 't2'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.failure, isNotNull);
    });
  });

  group('MergeTables', () {
    test('sums draft lines into target, clears source, renumbers rounds', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateDraftLines('t2', [drink]));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const MergeTables('t1', 't2'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final source = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(source.status, TableStatus.available);
      expect(bloc.state.rounds.length, 1);
      expect(bloc.state.rounds.single.tableId, 't2');
      // Round number should be renumbered to 1 (target had no rounds)
      expect(bloc.state.rounds.single.roundNumber, 1);
      // Only draft lines are merged (source draft 1 + target draft 1 = 2)
      // Fired lines are NOT added to draft
      expect(bloc.state.draftFor('t2').length, 2);
      expect(bloc.state.draftFor('t1'), isEmpty);
      // Target table keeps its status (available since no tab was opened on t2)
      final target = bloc.state.tables.firstWhere((t) => t.id == 't2');
      expect(target.status, TableStatus.available);
    });
  });

  group('ClearTab', () {
    test('clears tab and removes rounds', () async {
      await pumpLoad();
      await openTab('t1');
      bloc.add(const UpdateDraftLines('t1', [drink]));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const FireRound('t1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ClearTab('t1'));
      await expectLater(bloc.stream, emitsAnyOf([isA<TablesState>()]));
      await Future<void>.delayed(Duration.zero);

      final table = bloc.state.tables.firstWhere((t) => t.id == 't1');
      expect(table.status, TableStatus.available);
      expect(bloc.state.rounds, isEmpty);
      expect(roundRepo.all, isEmpty);
    });
  });
}
