import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_table_repository.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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
      final existingModel = _box.get(table.id);
      if (existingModel == null) {
        // New table - check if ID already exists (shouldn't happen with UUID, but defense in depth)
        if (_box.containsKey(table.id)) {
          return Left(
            DatabaseFailure('Table with ID already exists: ${table.id}'),
          );
        }
      }
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

  @override
  Future<Either<Failure, void>> fixDuplicateIds() async {
    try {
      final tables = _box.values.map((m) => m.toEntity()).toList();
      final seenIds = <String>{};
      final uuid = const Uuid();

      for (final table in tables) {
        if (seenIds.contains(table.id)) {
          // Duplicate ID found - generate new UUID
          final newId = uuid.v4();
          final updatedTable = table.copyWith(id: newId);
          final model = AppTableModel.fromEntity(updatedTable);
          await _box.delete(table.id);
          await _box.put(newId, model);
        } else {
          seenIds.add(table.id);
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to fix duplicate IDs: $e'));
    }
  }
}
