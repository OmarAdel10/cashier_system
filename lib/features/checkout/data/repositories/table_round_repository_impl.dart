import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_round_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_round_repository.dart';
import 'package:hive/hive.dart';

class TableRoundRepositoryImpl implements ITableRoundRepository {
  final Box<AppTableRoundModel> _box;

  TableRoundRepositoryImpl(this._box);

  @override
  Future<Either<Failure, List<TableRoundEntity>>> getRounds() async {
    try {
      final rounds = _box.values.map((m) => m.toEntity()).toList();
      return Right(rounds);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get rounds: $e'));
    }
  }

  @override
  Future<Either<Failure, List<TableRoundEntity>>> getRoundsForTable(
    String tableId,
  ) async {
    try {
      final rounds = _box.values
          .where((m) => m.tableId == tableId)
          .map((m) => m.toEntity())
          .toList();
      return Right(rounds);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get rounds for table: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveRound(TableRoundEntity round) async {
    try {
      final model = AppTableRoundModel.fromEntity(round);
      await _box.put(round.id, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save round: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRound(String id) async {
    try {
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete round: $e'));
    }
  }
}
