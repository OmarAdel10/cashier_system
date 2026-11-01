import 'package:daftari/core/error/either.dart';
import 'package:daftari/core/error/failure.dart';
import 'package:daftari/features/checkout/domain/entities/session_record_entity.dart';

abstract class ISessionRecordRepository {
  Future<Either<Failure, List<SessionRecordEntity>>> getSessionRecords({
    int? limit,
  });
  Future<Either<Failure, SessionRecordEntity?>> getSessionRecord(String id);
  Future<Either<Failure, void>> saveSessionRecord(SessionRecordEntity record);
  Future<Either<Failure, void>> deleteSessionRecord(String id);
}
