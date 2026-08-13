import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_station_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_station_repository.dart';
import 'package:hive/hive.dart';

class StationRepositoryImpl implements IStationRepository {
  static const _unset = Object();

  final Box<AppStationModel> _box;

  StationRepositoryImpl(this._box);

  @override
  Future<Either<Failure, List<StationEntity>>> getStations() async {
    try {
      final stations = _box.values.map((m) => m.toEntity()).toList();
      return Right(stations);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get stations: $e'));
    }
  }

  @override
  Future<Either<Failure, StationEntity?>> getStation(String id) async {
    try {
      final model = _box.get(id);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get station: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveStation(StationEntity station) async {
    try {
      final model = AppStationModel.fromEntity(station);
      await _box.put(station.id, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save station: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteStation(String id) async {
    try {
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete station: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateStationStatus(
    String id,
    StationStatus status, {
    Object? sessionStartTime = _unset,
    bool? isFixedDuration,
    Object? fixedDurationMinutes = _unset,
    Object? overtimeStartMinutes = _unset,
    Object? sessionTier = _unset,
    Object? addonLines = _unset,
  }) async {
    try {
      final model = _box.get(id);
      if (model == null) {
        return Left(DatabaseFailure('Station not found: $id'));
      }
      final base = model.toEntity();
      final updated = base.copyWith(
        status: status,
        sessionStartTime: identical(sessionStartTime, _unset)
            ? base.sessionStartTime
            : sessionStartTime as DateTime?,
        isFixedDuration: isFixedDuration ?? base.isFixedDuration,
        fixedDurationMinutes: identical(fixedDurationMinutes, _unset)
            ? base.fixedDurationMinutes
            : fixedDurationMinutes as int?,
        overtimeStartMinutes: identical(overtimeStartMinutes, _unset)
            ? base.overtimeStartMinutes
            : overtimeStartMinutes as int?,
        sessionTier: identical(sessionTier, _unset)
            ? base.sessionTier
            : sessionTier as PricingTier?,
        addonLines: identical(addonLines, _unset)
            ? base.addonLines
            : List<TableOrderLine>.from(addonLines as List),
      );
      await _box.put(id, AppStationModel.fromEntity(updated));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update station status: $e'));
    }
  }
}
