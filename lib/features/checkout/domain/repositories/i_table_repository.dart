import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';

abstract class ITableRepository {
  static const _unset = Object();

  Future<Either<Failure, List<TableEntity>>> getTables();
  Future<Either<Failure, TableEntity?>> getTable(String id);
  Future<Either<Failure, void>> saveTable(TableEntity table);
  Future<Either<Failure, void>> deleteTable(String id);

  /// Updates table session state. For [tabOpenedAt] and
  /// [activeRoundNumber], pass `null` to clear the value (they default to a
  /// sentinel meaning "keep current").
  Future<Either<Failure, void>> updateTableStatus(
    String id,
    TableStatus status, {
    Object? tabOpenedAt = _unset,
    Object? activeRoundNumber = _unset,
  });
}
