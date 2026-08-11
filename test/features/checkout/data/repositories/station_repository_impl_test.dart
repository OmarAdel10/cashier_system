import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_station_model.dart';
import 'package:cashier_system/features/checkout/data/repositories/station_repository_impl.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

void main() {
  group('StationRepositoryImpl', () {
    late Box<AppStationModel> box;
    late StationRepositoryImpl repo;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      if (!Hive.isAdapterRegistered(AppStationModelAdapter().typeId)) {
        Hive.registerAdapter(AppStationModelAdapter());
      }
    });

    setUp(() async {
      box = await Hive.openBox<AppStationModel>('test_stations');
      await box.clear();
      repo = StationRepositoryImpl(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_stations');
    });

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

    test('persists and clears sessionTier via updateStationStatus', () async {
      final save = await repo.saveStation(station);
      save.fold((f) => fail('unexpected failure: $f'), (_) {});

      final updated = await repo.updateStationStatus(
        'PS4-1',
        StationStatus.active,
        sessionStartTime: DateTime(2026, 7, 1, 10, 0),
        isFixedDuration: true,
        fixedDurationMinutes: 60,
        sessionTier: PricingTier.multi,
      );
      updated.fold((f) => fail('unexpected failure: $f'), (_) {});
      final loaded = await repo.getStation('PS4-1');
      final loadedStation = loaded.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(loadedStation?.sessionTier, PricingTier.multi);
      expect(loadedStation?.status, StationStatus.active);
      expect(loadedStation?.fixedDurationMinutes, 60);

      final cleared = await repo.updateStationStatus(
        'PS4-1',
        StationStatus.available,
        sessionStartTime: null,
        isFixedDuration: false,
        sessionTier: null,
      );
      cleared.fold((f) => fail('unexpected failure: $f'), (_) {});
      final afterClear = await repo.getStation('PS4-1');
      final clearedStation = afterClear.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(clearedStation?.sessionTier, isNull);
      expect(clearedStation?.sessionStartTime, isNull);
      expect(clearedStation?.isFixedDuration, isFalse);
    });

    test('save and get station', () async {
      await repo.saveStation(station);
      final result = await repo.getStation('PS4-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved?.id, 'PS4-1');
      expect(saved?.normalHourlyRate, 50.0);
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
      await repo.saveStation(station);
      await repo.updateStationStatus(
        'PS4-1',
        StationStatus.active,
        sessionStartTime: DateTime.now(),
      );
      final result = await repo.getStation('PS4-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved?.status, StationStatus.active);
      expect(saved?.sessionStartTime, isNotNull);
    });

    test('delete station', () async {
      await repo.saveStation(station);
      await repo.deleteStation('PS4-1');
      final result = await repo.getStation('PS4-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved, isNull);
    });

    test('update status with null clears session fields', () async {
      await repo.saveStation(station);
      await repo.updateStationStatus(
        'PS4-1',
        StationStatus.active,
        sessionStartTime: DateTime(2026, 1, 1),
        isFixedDuration: true,
        fixedDurationMinutes: 120,
      );
      await repo.updateStationStatus(
        'PS4-1',
        StationStatus.available,
        sessionStartTime: null,
        isFixedDuration: false,
        fixedDurationMinutes: null,
        overtimeStartMinutes: null,
      );
      final result = await repo.getStation('PS4-1');
      final saved = result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (value) => value,
      );
      expect(saved?.status, StationStatus.available);
      expect(saved?.sessionStartTime, isNull);
      expect(saved?.fixedDurationMinutes, isNull);
      expect(saved?.overtimeStartMinutes, isNull);
      expect(saved?.isFixedDuration, false);
    });
  });
}
