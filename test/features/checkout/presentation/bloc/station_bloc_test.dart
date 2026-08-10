import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
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
        await _waitFor(emissions, (s) => s.lastCompletedSession != null);

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
      await _waitFor(emissions, (s) => s.lastCompletedSession != null);

      await sub.cancel();
      final record = bloc.state.lastCompletedSession!;
      expect(record.tier, SessionTier.multi);
      expect(record.hourlyRate, 75);
      expect(record.minimumGameCost, 150);
      // 30 min * 75/h = 3750 piastres > 150 minimum.
      expect(record.subtotalPiastres, ((75 / 60) * 30 * 100).round());
    });
  });

  group('session lifecycle safety', () {
    test(
      'EndSession on station with no active session emits no record',
      () async {
        var now = DateTime(2026, 7, 1, 10, 0);
        repository = FakeStationRepository([ps4]);
        bloc = StationBloc(repository: repository, now: () => now);
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

        bloc.add(const EndSession(stationId: 'PS4-1'));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await sub.cancel();
        expect(bloc.state.lastCompletedSession, isNull);
        expect(emissions.where((s) => s.lastCompletedSession != null), isEmpty);
      },
    );

    test(
      'EndStation clears overtime and fixed duration in repository',
      () async {
        repository = FakeStationRepository([
          ps4.copyWith(
            status: StationStatus.active,
            sessionStartTime: DateTime(2026, 7, 1, 9, 0),
            isFixedDuration: true,
            fixedDurationMinutes: 120,
            overtimeStartMinutes: 30,
            sessionTier: PricingTier.multi,
          ),
        ]);
        bloc = StationBloc(
          repository: repository,
          now: () => DateTime(2026, 7, 1, 10, 0),
        );
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(
          emissions,
          (s) =>
              s.status == StationBlocStatus.ready &&
              s.stations.any((st) => st.status == StationStatus.active),
        );

        bloc.add(const EndSession(stationId: 'PS4-1'));
        await _waitFor(
          emissions,
          (s) => s.stations.any(
            (st) =>
                st.id == 'PS4-1' &&
                st.status == StationStatus.available &&
                st.sessionStartTime == null,
          ),
        );

        await sub.cancel();
        final stored = repository.all.first;
        expect(stored.sessionStartTime, isNull);
        expect(stored.isFixedDuration, false);
        expect(stored.fixedDurationMinutes, isNull);
        expect(stored.overtimeStartMinutes, isNull);
        expect(stored.sessionTier, isNull);
      },
    );

    test(
      'StartSession with unknown station sets failure and keeps stations',
      () async {
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(
          emissions,
          (s) => s.status == StationBlocStatus.ready && s.stations.length == 2,
        );

        bloc.add(
          const StartSession(stationId: 'NOPE-1', tier: PricingTier.normal),
        );
        await _waitFor(emissions, (s) => s.failure != null);

        await sub.cancel();
        expect(bloc.state.failure, isNotNull);
        expect(bloc.state.failure!.message, contains('NOPE-1'));
        expect(bloc.state.stations, hasLength(2));
        expect(
          bloc.state.stations.every((s) => s.status == StationStatus.available),
          true,
        );
      },
    );

    test(
      'EndSession with unknown station sets failure and keeps stations',
      () async {
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(
          emissions,
          (s) => s.status == StationBlocStatus.ready && s.stations.length == 2,
        );
        final stationsBefore = bloc.state.stations;

        bloc.add(const EndSession(stationId: 'NOPE-1'));
        await _waitFor(emissions, (s) => s.failure != null);

        await sub.cancel();
        expect(bloc.state.failure, isNotNull);
        expect(bloc.state.failure!.message, contains('NOPE-1'));
        expect(bloc.state.stations, same(stationsBefore));
      },
    );

    test('ConvertToOpenSession with unknown station sets failure', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) => s.status == StationBlocStatus.ready && s.stations.length == 2,
      );

      bloc.add(const ConvertToOpenSession(stationId: 'NOPE-1'));
      await _waitFor(emissions, (s) => s.failure != null);

      await sub.cancel();
      expect(bloc.state.failure, isNotNull);
      expect(bloc.state.stations, hasLength(2));
    });

    test(
      'ConvertToOpenSession without sessionStartTime sets failure',
      () async {
        repository = FakeStationRepository([
          ps4.copyWith(status: StationStatus.active),
        ]);
        bloc = StationBloc(repository: repository);
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

        bloc.add(const ConvertToOpenSession(stationId: 'PS4-1'));
        await _waitFor(emissions, (s) => s.failure != null);

        await sub.cancel();
        expect(bloc.state.failure, isNotNull);
        expect(bloc.state.stations.first.sessionStartTime, isNull);
      },
    );
  });

  group('station addons', () {
    const cola = TableOrderLine(
      name: 'Cola',
      barcode: 'PROD-1',
      quantity: 2,
      unitPricePiastres: 1500,
      prepCategory: PrepCategory.beverage,
    );
    const shisha = TableOrderLine(
      name: 'Shisha Apple',
      barcode: 'PROD-2',
      quantity: 1,
      unitPricePiastres: 5000,
      prepCategory: PrepCategory.shisha,
    );

    test('AddStationAddon appends line and persists in repository', () async {
      repository = FakeStationRepository([
        ps4.copyWith(status: StationStatus.active),
      ]);
      bloc = StationBloc(repository: repository);
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) =>
            s.status == StationBlocStatus.ready &&
            s.stations.any((st) => st.status == StationStatus.active),
      );

      bloc.add(const AddStationAddon(stationId: 'PS4-1', line: cola));
      await _waitFor(
        emissions,
        (s) => s.stations.any((st) => st.addonLines.length == 1),
      );

      await sub.cancel();
      final station = bloc.state.stations.first;
      expect(station.addonLines, [cola]);
      expect(repository.all.first.addonLines, [cola]);
    });

    test('AddStationAddon on inactive station sets failure', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) => s.status == StationBlocStatus.ready && s.stations.length == 2,
      );

      bloc.add(const AddStationAddon(stationId: 'PS4-1', line: cola));
      await _waitFor(emissions, (s) => s.failure != null);

      await sub.cancel();
      expect(bloc.state.failure!.message, contains('inactive'));
      expect(bloc.state.stations.first.addonLines, isEmpty);
    });

    test('SetStationAddons replaces the full line list', () async {
      repository = FakeStationRepository([
        ps4.copyWith(status: StationStatus.active, addonLines: const [cola]),
      ]);
      bloc = StationBloc(repository: repository);
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(
        emissions,
        (s) =>
            s.status == StationBlocStatus.ready &&
            s.stations.any((st) => st.addonLines.length == 1),
      );

      bloc.add(
        const SetStationAddons(stationId: 'PS4-1', lines: [cola, shisha]),
      );
      await _waitFor(
        emissions,
        (s) => s.stations.any((st) => st.addonLines.length == 2),
      );

      await sub.cancel();
      expect(bloc.state.stations.first.addonLines, [cola, shisha]);
      expect(repository.all.first.addonLines, [cola, shisha]);
    });

    test(
      'EndSession record includes addon lines and combined totals',
      () async {
        var now = DateTime(2026, 7, 1, 10, 0);
        repository = FakeStationRepository([
          ps4.copyWith(
            status: StationStatus.active,
            sessionStartTime: DateTime(2026, 7, 1, 9, 30),
            addonLines: const [cola, shisha],
          ),
        ]);
        bloc = StationBloc(repository: repository, now: () => now);
        final emissions = <StationState>[];
        final sub = bloc.stream.listen(emissions.add);

        bloc.add(const LoadStations());
        await _waitFor(
          emissions,
          (s) =>
              s.status == StationBlocStatus.ready &&
              s.stations.any(
                (st) => st.id == 'PS4-1' && st.status == StationStatus.active,
              ),
        );

        now = DateTime(2026, 7, 1, 10, 0);
        bloc.add(const EndSession(stationId: 'PS4-1'));
        await _waitFor(
          emissions,
          (s) =>
              s.lastCompletedSession != null &&
              s.lastCompletedSession!.addonLines.length == 2,
        );

        await sub.cancel();
        final record = bloc.state.lastCompletedSession!;
        final timeCharged = ((50 / 60) * 30 * 100).round();
        const addons = 2 * 1500 + 5000;
        expect(record.addonLines, [cola, shisha]);
        expect(record.subtotalPiastres, timeCharged + addons);
        expect(record.totalPiastres, timeCharged + addons);
      },
    );

    test('EndSession clears addon lines in state and repository', () async {
      repository = FakeStationRepository([
        ps4.copyWith(status: StationStatus.active, addonLines: const [cola]),
      ]);
      bloc = StationBloc(repository: repository);
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);

      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.status == StationBlocStatus.ready);

      bloc.add(const EndSession(stationId: 'PS4-1'));
      await _waitFor(
        emissions,
        (s) => s.stations.any(
          (st) => st.id == 'PS4-1' && st.status == StationStatus.available,
        ),
      );

      await sub.cancel();
      expect(bloc.state.stations.first.addonLines, isEmpty);
      expect(repository.all.first.addonLines, isEmpty);
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
      await _waitFor(
        emissions,
        (s) =>
            s.stations.length == 2 &&
            s.stations.any(
              (st) => st.id == 'PS4-1' && st.name == 'PS4-1-Renamed',
            ),
      );

      expect(bloc.state.stations, hasLength(2));
      expect(
        repository.all.firstWhere((s) => s.id == 'PS4-1').name,
        'PS4-1-Renamed',
      );

      await sub.cancel();
    });

    test('DeleteStation removes the station from state and repo', () async {
      final emissions = <StationState>[];
      final sub = bloc.stream.listen(emissions.add);
      bloc.add(const LoadStations());
      await _waitFor(emissions, (s) => s.stations.length == 2);

      bloc.add(const DeleteStation(stationId: 'BILLIARDS-1'));
      await _waitFor(emissions, (s) => s.stations.length == 1);

      expect(
        bloc.state.stations.map((s) => s.id),
        isNot(contains('BILLIARDS-1')),
      );
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
