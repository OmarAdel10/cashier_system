import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';

enum TablesStatus { initial, loading, ready, error }

class TablesState {
  final TablesStatus status;
  final Failure? failure;
  final List<TableEntity> tables;
  final List<TableRoundEntity> rounds;
  final Map<String, List<TableOrderLine>> drafts;

  const TablesState({
    this.status = TablesStatus.initial,
    this.failure,
    this.tables = const [],
    this.rounds = const [],
    this.drafts = const {},
  });

  List<TableOrderLine> draftFor(String tableId) => drafts[tableId] ?? const [];

  TablesState copyWith({
    TablesStatus? status,
    Failure? failure,
    bool clearFailure = false,
    List<TableEntity>? tables,
    List<TableRoundEntity>? rounds,
    Map<String, List<TableOrderLine>>? drafts,
  }) {
    return TablesState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      tables: tables ?? this.tables,
      rounds: rounds ?? this.rounds,
      drafts: drafts ?? this.drafts,
    );
  }
}
