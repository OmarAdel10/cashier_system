import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/services/auto_conversion_service.dart';
import '../../helpers/fake_station_repository.dart';

void main() {
  StationEntity fixedStation({
    required DateTime start,
    int? fixedMinutes = 60,
  }) {
    return StationEntity(
      id: 'PS4-1',
      name: 'PS4-1',
      parentCategory: 'PS4',
      stationType: StationType.playstation,
      normalHourlyRate: 50,
      multiHourlyRate: 75,
      minimumGameCostNormal: 100,
      minimumGameCostMulti: 150,
      iconAsset: 'a',
      status: StationStatus.active,
      sessionStartTime: start,
      isFixedDuration: true,
      fixedDurationMinutes: fixedMinutes,
    );
  }

  test('converts fixed station to open session after duration + grace', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 1, 10, 0);
      final station = fixedStation(
        start: DateTime(2026, 7, 1, 9, 0),
        fixedMinutes: 30,
      );
      final repository = FakeStationRepository([station]);
      final bloc = StationBloc(repository: repository, now: () => now);
      bloc.add(const LoadStations());

      final service = AutoConversionService(
        stationBloc: bloc,
        checkInterval: const Duration(seconds: 30),
        gracePeriod: const Duration(minutes: 5),
        now: () => now,
      );
      service.start();
      async.flushMicrotasks();

      // Elapsed 1h35m > 30m + 5m grace -> must convert.
      now = DateTime(2026, 7, 1, 10, 35);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();

      final converted = repository.all.first;
      expect(converted.status, StationStatus.active);
      expect(converted.isFixedDuration, isFalse);
      expect(converted.fixedDurationMinutes, isNull);
      expect(converted.overtimeStartMinutes, 95);

      service.dispose();
      bloc.close();
    });
  });

  test('does not convert when elapsed is below duration + grace', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 1, 10, 0);
      final station = fixedStation(
        start: DateTime(2026, 7, 1, 9, 0),
        fixedMinutes: 60,
      );
      final repository = FakeStationRepository([station]);
      final bloc = StationBloc(repository: repository, now: () => now);
      bloc.add(const LoadStations());

      final service = AutoConversionService(
        stationBloc: bloc,
        checkInterval: const Duration(seconds: 30),
        gracePeriod: const Duration(minutes: 5),
        now: () => now,
      );
      service.start();
      async.flushMicrotasks();

      // Elapsed 1h03m < 60m + 5m grace -> no conversion.
      now = DateTime(2026, 7, 1, 10, 3);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();

      final converted = repository.all.first;
      expect(converted.isFixedDuration, isTrue);
      expect(converted.fixedDurationMinutes, 60);

      service.dispose();
      bloc.close();
    });
  });

  test('ignores open sessions and fixed sessions without start time', () {
    fakeAsync((async) {
      var now = DateTime(2026, 7, 1, 10, 0);
      final openStation = StationEntity(
        id: 'open-1',
        name: 'Open-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50,
        multiHourlyRate: 75,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'a',
        status: StationStatus.active,
        sessionStartTime: DateTime(2026, 7, 1, 8, 0),
        isFixedDuration: false,
      );
      final noStart = fixedStation(
        start: DateTime(2026, 7, 1, 9, 0),
      ).copyWith(sessionStartTime: null);
      final repository = FakeStationRepository([openStation, noStart]);
      final bloc = StationBloc(repository: repository, now: () => now);
      bloc.add(const LoadStations());

      final service = AutoConversionService(
        stationBloc: bloc,
        checkInterval: const Duration(seconds: 30),
        gracePeriod: const Duration(minutes: 5),
        now: () => now,
      );
      service.start();
      async.flushMicrotasks();

      now = DateTime(2026, 7, 2, 10, 0);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();

      expect(repository.all.first.isFixedDuration, isFalse);
      expect(repository.all[1].fixedDurationMinutes, 60);

      service.dispose();
      bloc.close();
    });
  });
}
