import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';

abstract class IZoneRepository {
  Future<Either<Failure, List<ZoneEntity>>> getZones();
  Future<Either<Failure, void>> saveZone(ZoneEntity zone);
  Future<Either<Failure, void>> deleteZone(String id);
}
