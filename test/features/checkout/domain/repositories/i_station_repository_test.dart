import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_station_repository.dart';

class _FakeStationRepository implements IStationRepository {
  static const _unset = Object();

  final Map<String, StationEntity> _stations = {};

  @override
  Future<Either<Failure, List<StationEntity>>> getStations() async =>
      Right(_stations.values.toList());

  @override
  Future<Either<Failure, StationEntity?>> getStation(String id) async =>
      Right(_stations[id]);

  @override
  Future<Either<Failure, void>> saveStation(StationEntity station) async {
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
    Object? sessionTier = _unset,
    Object? addonLines = _unset,
  }) async {
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
        sessionTier: identical(sessionTier, _unset)
            ? station.sessionTier
            : sessionTier as PricingTier?,
        addonLines: identical(addonLines, _unset)
            ? station.addonLines
            : List<TableOrderLine>.from(addonLines as List),
      );
    }
    return const Right(null);
  }
}

void main() {
  late IStationRepository repo;

  setUp(() => repo = _FakeStationRepository());

  group('IStationRepository contract', () {
    test('save and get station', () async {
      const station = StationEntity(
        id: 'PS4-1',
        name: 'PS4-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50.0,
        multiHourlyRate: 75.0,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'assets/icons/ps4.svg',
      );
      await expectLater(repo.saveStation(station), completes);
      final result = await repo.getStation('PS4-1');
      final value = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(value?.id, 'PS4-1');
    });

    test('get all stations', () async {
      const s1 = StationEntity(
        id: 'PS4-1',
        name: 'PS4-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50,
        multiHourlyRate: 75,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'a',
      );
      const s2 = StationEntity(
        id: 'PS5-1',
        name: 'PS5-1',
        parentCategory: 'PS5',
        stationType: StationType.playstation,
        normalHourlyRate: 80,
        multiHourlyRate: 120,
        minimumGameCostNormal: 150,
        minimumGameCostMulti: 200,
        iconAsset: 'b',
      );
      await repo.saveStation(s1);
      await repo.saveStation(s2);
      final result = await repo.getStations();
      final stations = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(stations.length, 2);
    });

    test('update status', () async {
      const station = StationEntity(
        id: 'PS4-1',
        name: 'PS4-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50,
        multiHourlyRate: 75,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'a',
      );
      await repo.saveStation(station);
      await repo.updateStationStatus(
        'PS4-1',
        StationStatus.active,
        sessionStartTime: DateTime.now(),
      );
      final result = await repo.getStation('PS4-1');
      final updated = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(updated?.status, StationStatus.active);
    });
  });
}
