import 'package:daftari/core/error/either.dart';
import 'package:daftari/core/error/failure.dart';
import 'package:daftari/features/checkout/domain/entities/station_entity.dart';

abstract class IStationRepository {
  static const _unset = Object();

  Future<Either<Failure, List<StationEntity>>> getStations();
  Future<Either<Failure, StationEntity?>> getStation(String id);
  Future<Either<Failure, void>> saveStation(StationEntity station);
  Future<Either<Failure, void>> deleteStation(String id);

  /// Updates station session state. For [sessionStartTime],
  /// [fixedDurationMinutes] and [overtimeStartMinutes], pass `null` to
  /// clear the value (they default to a sentinel meaning "keep current").
  Future<Either<Failure, void>> updateStationStatus(
    String id,
    StationStatus status, {
    Object? sessionStartTime = _unset,
    bool? isFixedDuration,
    Object? fixedDurationMinutes = _unset,
    Object? overtimeStartMinutes = _unset,
    Object? sessionTier = _unset,
    Object? addonLines = _unset,
  });
}
