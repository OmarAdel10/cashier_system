import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_station_repository.dart';

class FakeStationRepository implements IStationRepository {
  static const _unset = Object();

  final Map<String, StationEntity> _stations = {};

  bool failOnGet = false;
  bool failOnSave = false;
  bool failOnUpdate = false;

  FakeStationRepository([List<StationEntity>? initial]) {
    for (final s in initial ?? const []) {
      _stations[s.id] = s;
    }
  }

  List<StationEntity> get all => _stations.values.toList();

  @override
  Future<Either<Failure, List<StationEntity>>> getStations() async {
    if (failOnGet) return Left(DatabaseFailure('boom'));
    return Right(all);
  }

  @override
  Future<Either<Failure, StationEntity?>> getStation(String id) async =>
      Right(_stations[id]);

  @override
  Future<Either<Failure, void>> saveStation(StationEntity station) async {
    if (failOnSave) return Left(DatabaseFailure('boom'));
    _stations[station.id] = station;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteStation(String id) async {
    _stations.remove(id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateStationStatus(
    String id,
    StationStatus status, {
    Object? sessionStartTime = _unset,
    bool? isFixedDuration,
    Object? fixedDurationMinutes = _unset,
    Object? overtimeStartMinutes = _unset,
  }) async {
    if (failOnUpdate) return Left(DatabaseFailure('boom'));
    final station = _stations[id];
    if (station != null) {
      _stations[id] = station.copyWith(
        status: status,
        sessionStartTime: identical(sessionStartTime, _unset)
            ? station.sessionStartTime
            : sessionStartTime as DateTime?,
        isFixedDuration: isFixedDuration ?? station.isFixedDuration,
        fixedDurationMinutes: identical(fixedDurationMinutes, _unset)
            ? station.fixedDurationMinutes
            : fixedDurationMinutes as int?,
        overtimeStartMinutes: identical(overtimeStartMinutes, _unset)
            ? station.overtimeStartMinutes
            : overtimeStartMinutes as int?,
      );
    }
    return const Right(null);
  }
}
