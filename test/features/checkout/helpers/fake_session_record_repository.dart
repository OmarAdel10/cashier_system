import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_session_record_repository.dart';

class FakeSessionRecordRepository implements ISessionRecordRepository {
  final Map<String, SessionRecordEntity> _records = {};

  bool failOnGet = false;
  bool failOnSave = false;

  FakeSessionRecordRepository([List<SessionRecordEntity>? initial]) {
    for (final r in initial ?? const []) {
      _records[r.id] = r;
    }
  }

  List<SessionRecordEntity> get all => _records.values.toList();

  @override
  Future<Either<Failure, List<SessionRecordEntity>>> getSessionRecords({
    int? limit,
  }) async {
    if (failOnGet) return Left(DatabaseFailure('boom'));
    final sorted = all.toList()
      ..sort((a, b) {
        final at = a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return Right(limit != null ? sorted.take(limit).toList() : sorted);
  }

  @override
  Future<Either<Failure, SessionRecordEntity?>> getSessionRecord(
    String id,
  ) async => Right(_records[id]);

  @override
  Future<Either<Failure, void>> saveSessionRecord(
    SessionRecordEntity record,
  ) async {
    if (failOnSave) return Left(DatabaseFailure('boom'));
    _records[record.id] = record;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteSessionRecord(String id) async {
    _records.remove(id);
    return const Right(null);
  }
}
