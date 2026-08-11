import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_session_record_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_session_record_repository.dart';
import 'package:hive/hive.dart';

class SessionRecordRepositoryImpl implements ISessionRecordRepository {
  final Box<AppSessionRecordModel> _box;

  SessionRecordRepositoryImpl(this._box);

  @override
  Future<Either<Failure, List<SessionRecordEntity>>> getSessionRecords({
    int? limit,
  }) async {
    try {
      final all = _box.values.map((m) => m.toEntity()).toList()
        ..sort((a, b) {
          final aTime = a.endTime ?? a.startTime;
          final bTime = b.endTime ?? b.startTime;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          return bTime.compareTo(aTime);
        });
      final records = limit != null && limit > 0 ? all.take(limit) : all;
      return Right(records.toList());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get session records: $e'));
    }
  }

  @override
  Future<Either<Failure, SessionRecordEntity?>> getSessionRecord(
    String id,
  ) async {
    try {
      final model = _box.get(id);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get session record: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSessionRecord(
    SessionRecordEntity record,
  ) async {
    try {
      await _box.put(record.id, AppSessionRecordModel.fromEntity(record));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save session record: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSessionRecord(String id) async {
    try {
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete session record: $e'));
    }
  }
}
