import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_repository.dart';
import 'package:hive/hive.dart';

class TableRepositoryImpl implements ITableRepository {
  static const _unset = Object();

  final Box<AppTableModel> _box;

  TableRepositoryImpl(this._box);

  @override
  Future<Either<Failure, List<TableEntity>>> getTables() async {
    try {
      final tables = _box.values.map((m) => m.toEntity()).toList();
      return Right(tables);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get tables: $e'));
    }
  }

  @override
  Future<Either<Failure, TableEntity?>> getTable(String id) async {
    try {
      final model = _box.get(id);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get table: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveTable(TableEntity table) async {
    try {
      final model = AppTableModel.fromEntity(table);
      await _box.put(table.id, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save table: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTable(String id) async {
    try {
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete table: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateTableStatus(
    String id,
    TableStatus status, {
    Object? tabOpenedAt = _unset,
    Object? activeRoundNumber = _unset,
  }) async {
    try {
      final model = _box.get(id);
      if (model == null) {
        return Left(DatabaseFailure('Table not found: $id'));
      }
      final base = model.toEntity();
      final updated = base.copyWith(
        status: status,
        tabOpenedAt: identical(tabOpenedAt, _unset)
            ? base.tabOpenedAt
            : tabOpenedAt as DateTime?,
        activeRoundNumber: identical(activeRoundNumber, _unset)
            ? base.activeRoundNumber
            : activeRoundNumber as int?,
      );
      await _box.put(id, AppTableModel.fromEntity(updated));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update table status: $e'));
    }
  }
}
