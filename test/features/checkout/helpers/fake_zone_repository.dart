import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_zone_repository.dart';

class FakeZoneRepository implements IZoneRepository {
  final Map<String, ZoneEntity> _zones = {};

  bool failOnGet = false;
  bool failOnSave = false;

  FakeZoneRepository([List<ZoneEntity>? initial]) {
    for (final z in initial ?? const []) {
      _zones[z.id] = z;
    }
  }

  List<ZoneEntity> get all => _zones.values.toList();

  @override
  Future<Either<Failure, List<ZoneEntity>>> getZones() async {
    if (failOnGet) return Left(DatabaseFailure('boom'));
    return Right(all);
  }

  @override
  Future<Either<Failure, void>> saveZone(ZoneEntity zone) async {
    if (failOnSave) return Left(DatabaseFailure('boom'));
    _zones[zone.id] = zone;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteZone(String id) async {
    _zones.remove(id);
    return const Right(null);
  }
}
