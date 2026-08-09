import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/ticket_routing.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_repository.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_round_repository.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_state.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

/// Prints kitchen/bar/shisha tickets for a fired round. Called once per
/// round with the routed lines; failures must not fail the round itself.
typedef TicketPrinter = Future<void> Function(List<TicketRoute> routes);

/// Reads the settings snapshot used for ticket routing at fire time.
typedef SettingsReader = AppSettingsEntity Function();

class TableBloc extends Bloc<TablesEvent, TablesState> {
  final ITableRepository _tableRepository;
  final ITableRoundRepository _roundRepository;
  final DateTime Function() _now;
  final TicketPrinter? _ticketPrinter;
  final SettingsReader? _settingsReader;

  TableBloc({
    required ITableRepository tableRepository,
    required ITableRoundRepository roundRepository,
    DateTime Function()? now,
    TicketPrinter? ticketPrinter,
    SettingsReader? settingsReader,
  }) : _tableRepository = tableRepository,
       _roundRepository = roundRepository,
       _now = now ?? DateTime.now,
       _ticketPrinter = ticketPrinter,
       _settingsReader = settingsReader,
       super(const TablesState()) {
    on<LoadTables>(_onLoadTables);
    on<SaveTable>(_onSaveTable);
    on<DeleteTable>(_onDeleteTable);
    on<OpenTab>(_onOpenTab);
    on<UpdateDraftLines>(_onUpdateDraftLines);
    on<FireRound>(_onFireRound);
    on<MarkServed>(_onMarkServed);
    on<StartCheckout>(_onStartCheckout);
    on<CompleteCheckout>(_onCompleteCheckout);
    on<TransferTable>(_onTransferTable);
    on<MergeTables>(_onMergeTables);
    on<ClearTab>(_onClearTab);
  }

  Future<void> _onLoadTables(
    LoadTables event,
    Emitter<TablesState> emit,
  ) async {
    emit(state.copyWith(status: TablesStatus.loading, clearFailure: true));
    final tablesResult = await _tableRepository.getTables();
    if (tablesResult.isLeft) {
      emit(
        state.copyWith(
          status: TablesStatus.error,
          failure: tablesResult.asLeft,
        ),
      );
      return;
    }
    final tables = tablesResult.asRight;
    final roundsResult = await _roundRepository.getRounds();
    if (roundsResult.isLeft) {
      emit(
        state.copyWith(
          status: TablesStatus.error,
          failure: roundsResult.asLeft,
        ),
      );
      return;
    }
    final rounds = roundsResult.asRight;
    emit(
      state.copyWith(
        status: TablesStatus.ready,
        tables: tables,
        rounds: rounds,
      ),
    );
  }

  Future<void> _onSaveTable(SaveTable event, Emitter<TablesState> emit) async {
    final result = await _tableRepository.saveTable(event.table);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          tables: [
            event.table,
            ...state.tables.where((t) => t.id != event.table.id),
          ],
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onDeleteTable(
    DeleteTable event,
    Emitter<TablesState> emit,
  ) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    if (table.status != TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Cannot delete table with an open tab: ${event.tableId}',
          ),
        ),
      );
      return;
    }
    final result = await _tableRepository.deleteTable(event.tableId);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          tables: state.tables.where((t) => t.id != event.tableId).toList(),
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onOpenTab(OpenTab event, Emitter<TablesState> emit) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    if (table.status != TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Only available tables can open a tab: ${event.tableId}',
          ),
        ),
      );
      return;
    }

    final result = await _tableRepository.updateTableStatus(
      event.tableId,
      TableStatus.occupied,
      tabOpenedAt: _now(),
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final updated = table.copyWith(
        status: TableStatus.occupied,
        tabOpenedAt: _now(),
      );
      emit(state.copyWith(tables: _replaceTable(updated), clearFailure: true));
    });
  }

  Future<void> _onUpdateDraftLines(
    UpdateDraftLines event,
    Emitter<TablesState> emit,
  ) async {
    emit(
      state.copyWith(
        drafts: {...state.drafts, event.tableId: event.lines},
        clearFailure: true,
      ),
    );
  }

  Future<void> _onFireRound(FireRound event, Emitter<TablesState> emit) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    if (table.status == TableStatus.available ||
        table.status == TableStatus.paymentPending) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Cannot fire a round without an open tab: ${event.tableId}',
          ),
        ),
      );
      return;
    }
    final lines = state.draftFor(event.tableId);
    if (lines.isEmpty) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Cannot fire an empty round: ${event.tableId}',
          ),
        ),
      );
      return;
    }

    final now = _now();
    final nextRound = (table.activeRoundNumber ?? 0) + 1;
    final round = TableRoundEntity(
      id: 'RND-$now-${event.tableId}',
      tableId: event.tableId,
      roundNumber: nextRound,
      lines: lines,
      firedAt: now,
    );

    final roundResult = await _roundRepository.saveRound(round);
    if (roundResult.isLeft) {
      emit(state.copyWith(failure: roundResult.asLeft));
      return;
    }
    final tableResult = await _tableRepository.updateTableStatus(
      event.tableId,
      TableStatus.orderPending,
      tabOpenedAt: table.tabOpenedAt,
      activeRoundNumber: nextRound,
    );
    if (tableResult.isLeft) {
      emit(state.copyWith(failure: tableResult.asLeft));
      return;
    }
    final updated = table.copyWith(
      status: TableStatus.orderPending,
      activeRoundNumber: nextRound,
    );
    emit(
      state.copyWith(
        tables: _replaceTable(updated),
        rounds: [...state.rounds, round],
        drafts: {...state.drafts}..remove(event.tableId),
        clearFailure: true,
      ),
    );
    await _printTickets(round);
  }

  Future<void> _onMarkServed(
    MarkServed event,
    Emitter<TablesState> emit,
  ) async {
    final round = _findRound(event.roundId);
    if (round == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Round not found: ${event.roundId}'),
        ),
      );
      return;
    }
    final updatedRound = round.copyWith(status: RoundStatus.served);
    final result = await _roundRepository.saveRound(updatedRound);
    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final table = _findTable(event.tableId);
      emit(
        state.copyWith(
          rounds: _replaceRound(updatedRound),
          tables: table == null
              ? state.tables
              : _replaceTable(table.copyWith(status: TableStatus.served)),
          clearFailure: true,
        ),
      );
    });
  }

  Future<void> _onStartCheckout(
    StartCheckout event,
    Emitter<TablesState> emit,
  ) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    if (table.status == TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Cannot start checkout on an available table: ${event.tableId}',
          ),
        ),
      );
      return;
    }
    final result = await _tableRepository.updateTableStatus(
      event.tableId,
      TableStatus.paymentPending,
      tabOpenedAt: table.tabOpenedAt,
    );
    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      emit(
        state.copyWith(
          tables: _replaceTable(
            table.copyWith(status: TableStatus.paymentPending),
          ),
          clearFailure: true,
        ),
      );
    });
  }

  Future<void> _onCompleteCheckout(
    CompleteCheckout event,
    Emitter<TablesState> emit,
  ) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    final result = await _tableRepository.updateTableStatus(
      event.tableId,
      TableStatus.available,
      tabOpenedAt: null,
      activeRoundNumber: null,
    );
    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      emit(
        state.copyWith(
          tables: _replaceTable(
            table.copyWith(
              status: TableStatus.available,
              tabOpenedAt: null,
              activeRoundNumber: null,
            ),
          ),
          drafts: {...state.drafts}..remove(event.tableId),
          clearFailure: true,
        ),
      );
    });
  }

  Future<void> _onTransferTable(
    TransferTable event,
    Emitter<TablesState> emit,
  ) async {
    final source = _findTable(event.sourceId);
    final target = _findTable(event.targetId);
    if (source == null || target == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Table not found: ${source == null ? event.sourceId : event.targetId}',
          ),
        ),
      );
      return;
    }
    if (source.status == TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Source table has no open tab: ${event.sourceId}',
          ),
        ),
      );
      return;
    }
    if (target.status != TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Target table is not available: ${event.targetId}',
          ),
        ),
      );
      return;
    }

    final sourceRounds = state.rounds
        .where((r) => r.tableId == event.sourceId)
        .toList();
    final movedRounds = [
      for (final r in sourceRounds) r.copyWith(tableId: event.targetId),
    ];

    for (final round in movedRounds) {
      final result = await _roundRepository.saveRound(round);
      if (result.isLeft) {
        emit(state.copyWith(failure: result.asLeft));
        return;
      }
    }

    final targetResult = await _tableRepository.updateTableStatus(
      event.targetId,
      source.status,
      tabOpenedAt: source.tabOpenedAt,
      activeRoundNumber: source.activeRoundNumber,
    );
    if (targetResult.isLeft) {
      emit(state.copyWith(failure: targetResult.asLeft));
      return;
    }
    final sourceResult = await _tableRepository.updateTableStatus(
      event.sourceId,
      TableStatus.available,
      tabOpenedAt: null,
      activeRoundNumber: null,
    );
    if (sourceResult.isLeft) {
      emit(state.copyWith(failure: sourceResult.asLeft));
      return;
    }
    emit(
      state.copyWith(
        tables: [
          for (final t in state.tables)
            if (t.id == event.sourceId)
              t.copyWith(
                status: TableStatus.available,
                tabOpenedAt: null,
                activeRoundNumber: null,
              )
            else if (t.id == event.targetId)
              t.copyWith(
                status: source.status,
                tabOpenedAt: source.tabOpenedAt,
                activeRoundNumber: source.activeRoundNumber,
              )
            else
              t,
        ],
        rounds: [
          for (final r in state.rounds)
            if (r.tableId == event.sourceId)
              r.copyWith(tableId: event.targetId)
            else
              r,
        ],
        drafts: {
          event.sourceId: const [],
          event.targetId: [
            ...state.draftFor(event.targetId),
            ...state.draftFor(event.sourceId),
          ],
        },
        clearFailure: true,
      ),
    );
  }

  Future<void> _onMergeTables(
    MergeTables event,
    Emitter<TablesState> emit,
  ) async {
    final source = _findTable(event.sourceId);
    final target = _findTable(event.targetId);
    if (source == null || target == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Table not found: ${source == null ? event.sourceId : event.targetId}',
          ),
        ),
      );
      return;
    }
    if (event.sourceId == event.targetId) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Cannot merge a table into itself'),
        ),
      );
      return;
    }
    if (source.status == TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Source table has no open tab: ${event.sourceId}',
          ),
        ),
      );
      return;
    }

    final sourceRounds = state.rounds
        .where((r) => r.tableId == event.sourceId)
        .toList();
    final movedRounds = [
      for (final r in sourceRounds) r.copyWith(tableId: event.targetId),
    ];
    for (final round in movedRounds) {
      final result = await _roundRepository.saveRound(round);
      if (result.isLeft) {
        emit(state.copyWith(failure: result.asLeft));
        return;
      }
    }

    final sourceResult = await _tableRepository.updateTableStatus(
      event.sourceId,
      TableStatus.available,
      tabOpenedAt: null,
      activeRoundNumber: null,
    );
    sourceResult.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final firedLines = [
        for (final r in sourceRounds)
          for (final line in r.lines) line,
      ];
      emit(
        state.copyWith(
          tables: [
            for (final t in state.tables)
              if (t.id == event.sourceId)
                t.copyWith(
                  status: TableStatus.available,
                  tabOpenedAt: null,
                  activeRoundNumber: null,
                )
              else
                t,
          ],
          rounds: [
            for (final r in state.rounds)
              if (r.tableId == event.sourceId)
                r.copyWith(tableId: event.targetId)
              else
                r,
          ],
          drafts: {
            event.sourceId: const [],
            event.targetId: [
              ...state.draftFor(event.targetId),
              ...state.draftFor(event.sourceId),
              ...firedLines,
            ],
          },
          clearFailure: true,
        ),
      );
    });
  }

  Future<void> _onClearTab(ClearTab event, Emitter<TablesState> emit) async {
    final table = _findTable(event.tableId);
    if (table == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Table not found: ${event.tableId}'),
        ),
      );
      return;
    }
    if (table.status == TableStatus.available) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Cannot clear an available table: ${event.tableId}',
          ),
        ),
      );
      return;
    }
    final rounds = state.rounds.where((r) => r.tableId == event.tableId);
    for (final round in rounds) {
      final result = await _roundRepository.deleteRound(round.id);
      if (result.isLeft) {
        emit(state.copyWith(failure: result.asLeft));
        return;
      }
    }
    final result = await _tableRepository.updateTableStatus(
      event.tableId,
      TableStatus.available,
      tabOpenedAt: null,
      activeRoundNumber: null,
    );
    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      emit(
        state.copyWith(
          tables: _replaceTable(
            table.copyWith(
              status: TableStatus.available,
              tabOpenedAt: null,
              activeRoundNumber: null,
            ),
          ),
          rounds: state.rounds
              .where((r) => r.tableId != event.tableId)
              .toList(),
          drafts: {...state.drafts}..remove(event.tableId),
          clearFailure: true,
        ),
      );
    });
  }

  /// Routes and prints kitchen/bar/shisha tickets for a fired round.
  /// Printing failures never fail the round (order already persisted).
  Future<void> _printTickets(TableRoundEntity round) async {
    final printer = _ticketPrinter;
    final reader = _settingsReader;
    if (printer == null || reader == null) return;
    final routes = routeTickets(settings: reader(), lines: round.lines);
    if (routes.isEmpty) return;
    try {
      await printer(routes);
    } catch (_) {
      // Ticket print failure is non-fatal for the round lifecycle.
    }
  }

  TableEntity? _findTable(String id) {
    for (final table in state.tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  TableRoundEntity? _findRound(String id) {
    for (final round in state.rounds) {
      if (round.id == id) return round;
    }
    return null;
  }

  List<TableEntity> _replaceTable(TableEntity updated) => [
    for (final t in state.tables) t.id == updated.id ? updated : t,
  ];

  List<TableRoundEntity> _replaceRound(TableRoundEntity updated) => [
    for (final r in state.rounds) r.id == updated.id ? updated : r,
  ];
}

extension _EitherAccess<T> on Either<Failure, T> {
  bool get isLeft => this is Left<Failure, T>;
  Failure get asLeft => (this as Left<Failure, T>).value;
  T get asRight => (this as Right<Failure, T>).value;
}
