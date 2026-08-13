import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

abstract class ISessionRecordRepository {
  Future<Either<Failure, List<SessionRecordEntity>>> getSessionRecords({
    int? limit,
  });
  Future<Either<Failure, SessionRecordEntity?>> getSessionRecord(String id);
  Future<Either<Failure, void>> saveSessionRecord(SessionRecordEntity record);
  Future<Either<Failure, void>> deleteSessionRecord(String id);
}
