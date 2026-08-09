import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_state.dart';
import '../../helpers/fake_zone_repository.dart';

void main() {
  group('ZoneBloc', () {
    test('loads zones and emits ready', () async {
      final repo = FakeZoneRepository(const [
        ZoneEntity(id: 'hall', name: 'Hall', kind: ZoneKind.dineIn),
        ZoneEntity(id: 'street', name: 'Street', kind: ZoneKind.takeaway),
      ]);
      final bloc = ZoneBloc(repository: repo);
      bloc.add(const LoadZones());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ZoneState>().having(
            (s) => s.status,
            'status',
            ZoneBlocStatus.loading,
          ),
          isA<ZoneState>()
              .having((s) => s.status, 'status', ZoneBlocStatus.ready)
              .having((s) => s.zones.length, 'zones length', 2),
        ]),
      );
      expect(bloc.state.zones.map((z) => z.name), ['Hall', 'Street']);
      await bloc.close();
    });

    test('load failure emits error', () async {
      final repo = FakeZoneRepository()..failOnGet = true;
      final bloc = ZoneBloc(repository: repo);
      bloc.add(const LoadZones());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ZoneState>().having(
            (s) => s.status,
            'status',
            ZoneBlocStatus.loading,
          ),
          isA<ZoneState>()
              .having((s) => s.status, 'status', ZoneBlocStatus.error)
              .having((s) => s.failure, 'failure', isA<DatabaseFailure>()),
        ]),
      );
      await bloc.close();
    });

    test('saveZone replaces existing zone and keeps order', () async {
      final repo = FakeZoneRepository();
      final bloc = ZoneBloc(repository: repo);
      bloc.add(const LoadZones());
      await bloc.stream.firstWhere((s) => s.status == ZoneBlocStatus.ready);

      bloc.add(
        const SaveZone(
          zone: ZoneEntity(id: 'hall', name: 'Hall'),
        ),
      );
      await expectLater(
        bloc.stream,
        emits(
          isA<ZoneState>().having((s) => s.zones.single.name, 'name', 'Hall'),
        ),
      );

      bloc.add(
        const SaveZone(
          zone: ZoneEntity(id: 'hall', name: 'Main Hall'),
        ),
      );
      await expectLater(
        bloc.stream,
        emits(
          isA<ZoneState>().having(
            (s) => s.zones.single.name,
            'name',
            'Main Hall',
          ),
        ),
      );
      expect(repo.all.length, 1);
      await bloc.close();
    });

    test('deleteZone removes zone', () async {
      final repo = FakeZoneRepository(const [
        ZoneEntity(id: 'hall', name: 'Hall'),
        ZoneEntity(id: 'take', name: 'Takeaway', kind: ZoneKind.takeaway),
      ]);
      final bloc = ZoneBloc(repository: repo);
      bloc.add(const LoadZones());
      await bloc.stream.firstWhere((s) => s.status == ZoneBlocStatus.ready);

      bloc.add(const DeleteZone(zoneId: 'hall'));
      await expectLater(
        bloc.stream,
        emits(
          isA<ZoneState>().having(
            (s) => s.zones.single.id,
            'remaining',
            'take',
          ),
        ),
      );
      expect(repo.all.single.id, 'take');
      await bloc.close();
    });

    test('save failure surfaces failure state', () async {
      final repo = FakeZoneRepository()..failOnSave = true;
      final bloc = ZoneBloc(repository: repo);
      bloc.add(const LoadZones());
      await bloc.stream.firstWhere((s) => s.status == ZoneBlocStatus.ready);

      bloc.add(
        const SaveZone(
          zone: ZoneEntity(id: 'x', name: 'X'),
        ),
      );
      await expectLater(
        bloc.stream,
        emits(
          isA<ZoneState>().having(
            (s) => s.failure,
            'failure',
            isA<DatabaseFailure>(),
          ),
        ),
      );
      await bloc.close();
    });
  });
}
