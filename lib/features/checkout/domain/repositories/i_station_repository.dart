import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

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
  });
}
