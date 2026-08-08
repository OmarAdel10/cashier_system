import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

abstract class IStationRepository {
  Future<Either<Failure, List<StationEntity>>> getStations();
  Future<Either<Failure, StationEntity?>> getStation(String id);
  Future<Either<Failure, void>> saveStation(StationEntity station);
  Future<Either<Failure, void>> deleteStation(String id);
  Future<Either<Failure, void>> updateStationStatus(
    String id,
    StationStatus status, {
    DateTime? sessionStartTime,
    bool? isFixedDuration,
    int? fixedDurationMinutes,
    int? overtimeStartMinutes,
  });
}
