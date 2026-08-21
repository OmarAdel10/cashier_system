import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_repository.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_round_repository.dart';

class FakeTableRepository implements ITableRepository {
  static const _unset = Object();

  final Map<String, TableEntity> _tables = {};

  bool failOnGet = false;
  bool failOnSave = false;
  bool failOnUpdate = false;

  FakeTableRepository([List<TableEntity>? initial]) {
    for (final t in initial ?? const []) {
      _tables[t.id] = t;
    }
  }

  List<TableEntity> get all => _tables.values.toList();

  @override
  Future<Either<Failure, List<TableEntity>>> getTables() async {
    if (failOnGet) return Left(DatabaseFailure('boom'));
    return Right(all);
  }

  @override
  Future<Either<Failure, TableEntity?>> getTable(String id) async =>
      Right(_tables[id]);

  @override
  Future<Either<Failure, void>> saveTable(TableEntity table) async {
    if (failOnSave) return Left(DatabaseFailure('boom'));
    _tables[table.id] = table;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteTable(String id) async {
    _tables.remove(id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateTableStatus(
    String id,
    TableStatus status, {
    Object? tabOpenedAt = _unset,
    Object? activeRoundNumber = _unset,
  }) async {
    if (failOnUpdate) return Left(DatabaseFailure('boom'));
    final table = _tables[id];
    if (table != null) {
      _tables[id] = table.copyWith(
        status: status,
        tabOpenedAt: identical(tabOpenedAt, _unset)
            ? table.tabOpenedAt
            : tabOpenedAt as DateTime?,
        activeRoundNumber: identical(activeRoundNumber, _unset)
            ? table.activeRoundNumber
            : activeRoundNumber as int?,
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> fixDuplicateIds() async {
    return const Right(null);
  }
}

class FakeRoundRepository implements ITableRoundRepository {
  final Map<String, TableRoundEntity> _rounds = {};

  bool failOnGet = false;
  bool failOnSave = false;

  FakeRoundRepository([List<TableRoundEntity>? initial]) {
    for (final r in initial ?? const []) {
      _rounds[r.id] = r;
    }
  }

  List<TableRoundEntity> get all => _rounds.values.toList();

  @override
  Future<Either<Failure, List<TableRoundEntity>>> getRounds() async {
    if (failOnGet) return Left(DatabaseFailure('boom'));
    return Right(all);
  }

  @override
  Future<Either<Failure, List<TableRoundEntity>>> getRoundsForTable(
    String tableId,
  ) async => Right(all.where((r) => r.tableId == tableId).toList());

  @override
  Future<Either<Failure, void>> saveRound(TableRoundEntity round) async {
    if (failOnSave) return Left(DatabaseFailure('boom'));
    _rounds[round.id] = round;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteRound(String id) async {
    _rounds.remove(id);
    return const Right(null);
  }
}
