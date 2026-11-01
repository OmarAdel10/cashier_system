import 'package:daftari/core/error/either.dart';
import 'package:daftari/core/error/failure.dart';
import 'package:daftari/features/checkout/domain/entities/zone_entity.dart';

abstract class IZoneRepository {
  Future<Either<Failure, List<ZoneEntity>>> getZones();
  Future<Either<Failure, void>> saveZone(ZoneEntity zone);
  Future<Either<Failure, void>> deleteZone(String id);
}
