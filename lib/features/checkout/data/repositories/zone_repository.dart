import 'package:hive/hive.dart';

import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/zone_entity.dart';
import '../../domain/repositories/i_zone_repository.dart';
import '../models/app_zone_model.dart';

class ZoneRepository implements IZoneRepository {
  final BusinessType _businessType;
  final Box<AppZoneModel> _box;

  ZoneRepository({
    required BusinessType businessType,
    required Box<AppZoneModel> box,
  }) : _businessType = businessType,
       _box = box;

  @override
  Future<Either<Failure, List<ZoneEntity>>> getZones() async {
    try {
      if (_box.isEmpty) {
        final presets =
            BusinessTypeRegistry.defaultZones[_businessType] ?? const [];
        if (presets.isNotEmpty) {
          for (final zone in presets) {
            await _box.put(zone.id, AppZoneModel.fromEntity(zone));
          }
        }
      }
      return Right(_box.values.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get zones: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveZone(ZoneEntity zone) async {
    try {
      await _box.put(zone.id, AppZoneModel.fromEntity(zone));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save zone: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteZone(String id) async {
    try {
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete zone: $e'));
    }
  }
}
