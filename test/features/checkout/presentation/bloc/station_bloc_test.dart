import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_state.dart';
import '../../helpers/fake_station_repository.dart';

void main() {
  late FakeStationRepository repository;
  late StationBloc bloc;

  const ps4 = StationEntity(
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

  const billiards = StationEntity(
    id: 'BILLIARDS-1',
    name: 'Billiards-1',
    parentCategory: 'Billiards',
    stationType: StationType.table,
    normalHourlyRate: 40,
    multiHourlyRate: 40,
    minimumGameCostNormal: 80,
    minimumGameCostMulti: 80,
    iconAsset: 'b',
  );

  setUp(() {
    repository = FakeStationRepository([ps4, billiards]);
    bloc = StationBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have initial status with empty stations', () {
      expect(bloc.state.status, StationBlocStatus.initial);
      expect(bloc.state.stations, isEmpty);
      expect(bloc.state.failure, isNull);
    });
  });

  group('LoadStations', () {
    test('emits loading then ready with all stations', () async {
      bloc.add(const LoadStations());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<StationState>((s) => s.status == StationBlocStatus.loading),
          predicate<StationState>(
            (s) =>
                s.status == StationBlocStatus.ready && s.stations.length == 2,
          ),
        ]),
      );
    });

    test('emits error when repository fails', () async {
      repository.failOnGet = true;

      bloc.add(const LoadStations());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<StationState>((s) => s.status == StationBlocStatus.loading),
          predicate<StationState>(
            (s) => s.status == StationBlocStatus.error && s.failure != null,
          ),
        ]),
      );
    });
  });

  group('StartSession', () {
    test('updates status to active with session start time', () async {
      bloc.add(const LoadStations());
      await bloc.stream.where((s) => s.status == StationBlocStatus.ready).first;

      bloc.add(
        const StartSession(
          stationId: 'PS4-1',
          tier: PricingTier.normal,
          isFixedDuration: false,
        ),
      );

      final state = await bloc.stream
          .where((s) => s.status == StationBlocStatus.ready)
          .first;
      final station = state.stations.firstWhere((s) => s.id == 'PS4-1');
      expect(station.status, StationStatus.active);
      expect(station.sessionStartTime, isNotNull);
    });
  });

  group('EndSession', () {
    test('converts fixed duration session back to available', () async {
      // Single subscription: no broadcast-stream events are lost, unlike
      // repeated `.first`/`.firstWhere` on a broadcast stream.
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) => s.status == StationBlocStatus.ready && s.stations.length == 2,
      );

      bloc.add(
        const StartSession(
          stationId: 'PS4-1',
          tier: PricingTier.normal,
          isFixedDuration: true,
          fixedDurationMinutes: 120,
        ),
      );
      await _waitFor(
        emissions,
        (s) => s.stations.any(
          (st) => st.id == 'PS4-1' && st.status == StationStatus.active,
        ),
      );

      bloc.add(const EndSession(stationId: 'PS4-1'));
      // The end-state of PS4-1 (available, no session start) is identical to
      // the initial load emission, so only look at emissions AFTER the
      // active one was seen.
      final afterActive = emissions.indexWhere(
        (s) => s.stations.any(
          (st) => st.id == 'PS4-1' && st.status == StationStatus.active,
        ),
      );
      await _waitFor(
        emissions,
        (s) => s.stations.any(
          (st) =>
              st.id == 'PS4-1' &&
              st.status == StationStatus.available &&
              st.sessionStartTime == null,
        ),
        from: afterActive + 1,
      );

      await sub.cancel();

      final station = bloc.state.stations.firstWhere((s) => s.id == 'PS4-1');
      expect(station.status, StationStatus.available);
      expect(station.sessionStartTime, isNull);
      expect(station.isFixedDuration, false);
    });
  });

  group('EndSession record', () {
    test('persists tier on StartSession and clears on EndSession', () async {
      var now = DateTime(2026, 7, 1, 10, 0);
      repository = FakeStationRepository([ps4]);
      bloc = StationBloc(repository: repository, now: () => now);
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) => s.status == StationBlocStatus.ready && s.stations.length == 1,
      );

      bloc.add(const StartSession(stationId: 'PS4-1', tier: PricingTier.multi));
      await _waitFor(
        emissions,
        (s) => s.stations.any(
          (st) =>
              st.id == 'PS4-1' &&
              st.status == StationStatus.active &&
              st.sessionTier == PricingTier.multi,
        ),
      );
      expect(repository.all.first.sessionTier, PricingTier.multi);

      bloc.add(const EndSession(stationId: 'PS4-1'));
      await _waitFor(
        emissions,
        (s) =>
            s.lastCompletedSession != null &&
            s.stations.every((st) => st.sessionTier == null),
        from:
            emissions.indexWhere(
              (s) => s.stations.any(
                (st) => st.id == 'PS4-1' && st.sessionTier == PricingTier.multi,
              ),
            ) +
            1,
      );

      await sub.cancel();
      expect(repository.all.first.sessionTier, isNull);
      expect(bloc.state.stations.first.sessionTier, isNull);
    });

    test(
      'composes record with booked fixed duration and minimum cost',
      () async {
        var now = DateTime(2026, 7, 1, 10, 0);
        repository = FakeStationRepository([ps4]);
        bloc = StationBloc(repository: repository, now: () => now);
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

        bloc.add(
          const StartSession(
            stationId: 'PS4-1',
            tier: PricingTier.normal,
            isFixedDuration: true,
            fixedDurationMinutes: 60,
          ),
        );
        await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

        now = DateTime(2026, 7, 1, 11, 20); // 80 min elapsed > 60 booked.
        bloc.add(const EndSession(stationId: 'PS4-1'));
        await _waitFor(
          emissions,
          (s) => s.lastCompletedSession != null,
          from:
              emissions.indexWhere(
                (s) => s.stations.any(
                  (st) =>
                      st.id == 'PS4-1' && st.status == StationStatus.available,
                ),
              ) +
              1,
        );

        await sub.cancel();
        final record = bloc.state.lastCompletedSession!;
        expect(record.stationId, 'PS4-1');
        expect(record.tier, SessionTier.normal);
        expect(record.wasFixedDuration, true);
        expect(record.durationMinutes, 80); // booked 60 + overtime 20.
        expect(record.subtotalPiastres, ((50 / 60) * 80 * 100).round());
        expect(record.totalPiastres, record.subtotalPiastres);
        expect(record.startTime, DateTime(2026, 7, 1, 10, 0));
        expect(record.endTime, DateTime(2026, 7, 1, 11, 20));
      },
    );

    test('multi tier uses multi rates and minimum cost', () async {
      var now = DateTime(2026, 7, 1, 10, 0);
      repository = FakeStationRepository([ps4]);
      bloc = StationBloc(repository: repository, now: () => now);
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

      bloc.add(const StartSession(stationId: 'PS4-1', tier: PricingTier.multi));
      await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

      now = DateTime(2026, 7, 1, 10, 30);
      bloc.add(const EndSession(stationId: 'PS4-1'));
      await _waitFor(
        emissions,
        (s) => s.lastCompletedSession != null,
        from:
            emissions.indexWhere(
              (s) => s.stations.any(
                (st) =>
                    st.id == 'PS4-1' && st.status == StationStatus.available,
              ),
            ) +
            1,
      );

      await sub.cancel();
      final record = bloc.state.lastCompletedSession!;
      expect(record.tier, SessionTier.multi);
      expect(record.hourlyRate, 75);
      expect(record.minimumGameCost, 150);
      // 30 min * 75/h = 3750 piastres > 150 minimum.
      expect(record.subtotalPiastres, ((75 / 60) * 30 * 100).round());
    });
  });

  group('station management', () {
    test('SaveStation adds a new station to state and repo', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.stations.length == 2);

      const newStation = StationEntity(
        id: 'PS4-2',
        name: 'PS4-2',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50,
        multiHourlyRate: 75,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'a',
      );
      bloc.add(SaveStation(station: newStation));
      await _waitFor(emissions, (s) => s.stations.length == 3);

      expect(bloc.state.stations.map((s) => s.id), contains('PS4-2'));
      expect(repository.all.map((s) => s.id), contains('PS4-2'));

      await sub.cancel();
    });

    test('SaveStation updates an existing station in place', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.stations.length == 2);

      const renamed = StationEntity(
        id: 'PS4-1',
        name: 'PS4-1-Renamed',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 60,
        multiHourlyRate: 85,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'a',
      );
      bloc.add(SaveStation(station: renamed));
      await _waitFor(emissions, (s) => s.stations.length == 2 &&
          s.stations.any((st) => st.id == 'PS4-1' && st.name == 'PS4-1-Renamed'));

      expect(bloc.state.stations, hasLength(2));
      expect(repository.all.firstWhere((s) => s.id == 'PS4-1').name, 'PS4-1-Renamed');

      await sub.cancel();
    });

    test('DeleteStation removes the station from state and repo', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.stations.length == 2);

      bloc.add(const DeleteStation(stationId: 'BILLIARDS-1'));
      await _waitFor(emissions, (s) => s.stations.length == 1);

      expect(bloc.state.stations.map((s) => s.id), isNot(contains('BILLIARDS-1')));
      expect(repository.all.map((s) => s.id), isNot(contains('BILLIARDS-1')));

      await sub.cancel();
    });
  });
}

Future<void> _waitFor(
  List<StationState> emissions,
  bool Function(StationState) test, {
  int from = 0,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!emissions.skip(from).any(test)) {
    if (DateTime.now().isAfter(deadline)) {
      final snapshot = emissions
          .skip(from)
          .map(
            (s) =>
                '${s.status.name}:${s.stations.map((st) => '${st.id}=${st.status.name}/${st.sessionStartTime != null}').join(',')}',
          )
          .join(' | ');
      fail('timed out waiting for station state emission. seen: $snapshot');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
