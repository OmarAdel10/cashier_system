import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';

abstract class ITableRoundRepository {
  Future<Either<Failure, List<TableRoundEntity>>> getRounds();
  Future<Either<Failure, List<TableRoundEntity>>> getRoundsForTable(
    String tableId,
  );
  Future<Either<Failure, void>> saveRound(TableRoundEntity round);
  Future<Either<Failure, void>> deleteRound(String id);
}
