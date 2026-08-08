import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/session_record_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/session_record_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/session_record_state.dart';
import '../../helpers/fake_session_record_repository.dart';

void main() {
  late FakeSessionRecordRepository repository;
  late SessionRecordBloc bloc;

  SessionRecordEntity record({String id = 'REC-1', DateTime? startTime}) {
    return SessionRecordEntity(
      id: id,
      shiftId: 'SHIFT-1',
      stationId: 'PS4-1',
      stationName: 'PS4-1',
      parentCategory: 'PS4',
      tier: SessionTier.normal,
      startTime: startTime ?? DateTime(2026, 8, 1, 10, 0),
      endTime: DateTime(2026, 8, 1, 11, 0),
      durationMinutes: 60,
      wasFixedDuration: false,
      hourlyRate: 50,
      minimumGameCost: 100,
      subtotalPiastres: 5000,
      totalPiastres: 5000,
      username: 'cashier1',
    );
  }

  setUp(() {
    repository = FakeSessionRecordRepository();
    bloc = SessionRecordBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have initial status with empty records', () {
      expect(bloc.state.status, SessionRecordBlocStatus.initial);
      expect(bloc.state.records, isEmpty);
      expect(bloc.state.failure, isNull);
    });
  });

  group('LoadSessionRecords', () {
    test('emits loading then ready with records sorted newest first', () async {
      repository.saveSessionRecord(
        record(id: 'REC-OLD', startTime: DateTime(2026, 7, 1, 9, 0)),
      );
      repository.saveSessionRecord(
        record(id: 'REC-NEW', startTime: DateTime(2026, 7, 1, 12, 0)),
      );
      bloc.add(const LoadSessionRecords());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SessionRecordState>(
            (s) => s.status == SessionRecordBlocStatus.loading,
          ),
          predicate<SessionRecordState>(
            (s) =>
                s.status == SessionRecordBlocStatus.ready &&
                s.records.length == 2 &&
                s.records.first.id == 'REC-NEW',
          ),
        ]),
      );
    });

    test('emits error when repository fails', () async {
      repository.failOnGet = true;
      bloc.add(const LoadSessionRecords());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SessionRecordState>(
            (s) => s.status == SessionRecordBlocStatus.loading,
          ),
          predicate<SessionRecordState>(
            (s) =>
                s.status == SessionRecordBlocStatus.error && s.failure != null,
          ),
        ]),
      );
    });
  });

  group('CreateSessionRecord', () {
    test('saves record and refreshes the list', () async {
      repository.saveSessionRecord(record(id: 'EXISTING'));
      bloc.add(CreateSessionRecord(record: record(id: 'REC-NEW')));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SessionRecordState>(
            (s) =>
                s.status == SessionRecordBlocStatus.ready &&
                s.records.any((r) => r.id == 'REC-NEW') &&
                s.records.any((r) => r.id == 'EXISTING'),
          ),
        ]),
      );
      expect(repository.all.map((r) => r.id), contains('REC-NEW'));
    });

    test('keeps state and surfaces failure when save fails', () async {
      repository.failOnSave = true;
      bloc.add(CreateSessionRecord(record: record()));

      await expectLater(
        bloc.stream,
        emitsInOrder([predicate<SessionRecordState>((s) => s.failure != null)]),
      );
    });
  });

  group('DeleteSessionRecord', () {
    test('removes record from state', () async {
      repository.saveSessionRecord(record(id: 'REC-1'));
      bloc.add(const LoadSessionRecords());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SessionRecordState>(
            (s) => s.status == SessionRecordBlocStatus.loading,
          ),
          predicate<SessionRecordState>(
            (s) => s.status == SessionRecordBlocStatus.ready,
          ),
        ]),
      );

      bloc.add(const DeleteSessionRecord(id: 'REC-1'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SessionRecordState>(
            (s) => !s.records.any((r) => r.id == 'REC-1'),
          ),
        ]),
      );
    });
  });
}
