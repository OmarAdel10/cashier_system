import 'package:daftari/core/error/either.dart';
import 'package:daftari/core/error/failure.dart';
import 'package:daftari/features/checkout/domain/entities/table_round_entity.dart';

abstract class ITableRoundRepository {
  Future<Either<Failure, List<TableRoundEntity>>> getRounds();
  Future<Either<Failure, List<TableRoundEntity>>> getRoundsForTable(
    String tableId,
  );
  Future<Either<Failure, void>> saveRound(TableRoundEntity round);
  Future<Either<Failure, void>> deleteRound(String id);
}
