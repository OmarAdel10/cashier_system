import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_state.dart';
import '../../helpers/fake_shifts_repository.dart';

class FailingFakeShiftsRepository implements IShiftsRepository {
  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, void>> closeOpenShifts(String username) async =>
      Left(DatabaseFailure('DB error'));
}

void main() {
  late ShiftBloc bloc;
  late FakeShiftsRepository repository;

  setUp(() {
    repository = FakeShiftsRepository();
    bloc = ShiftBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  Future<void> waitForState(ShiftBloc bloc, bool Function(ShiftState) predicate) async {
    for (var i = 0; i < 2000; i++) {
      if (predicate(bloc.state)) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('state never reached predicate (status=${bloc.state.status})');
  }

  group('initial state', () {
    test('should have initial status', () {
      expect(bloc.state.status, ShiftStatus.initial);
      expect(bloc.state.shift, isNull);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.orphanRecovered, false);
    });
  });

  group('StartShift', () {
    test('should start shift successfully', () async {
      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.shift?.username == 'cashier1' &&
              s.shift?.endedAt == null),
        ]),
      );
    });

    test('should ignore duplicate start while loading', () async {
      bloc.add(const StartShift('cashier1'));
      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) => s.status == ShiftStatus.active),
        ]),
      );
    });

    test('should clear stale shift from previous session on start', () async {
      bloc.add(const StartShift('userA'));
      await waitForState(bloc, (s) => s.status == ShiftStatus.active);

      bloc.add(const EndShift());
      await waitForState(bloc, (s) => s.status == ShiftStatus.ended);

      bloc.add(const StartShift('userB'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.loading && s.shift == null),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.shift?.username == 'userB' &&
              s.orphanRecovered == false),
        ]),
      );
    });
  });

  group('EndShift', () {
    test('should end active shift', () async {
      bloc.add(const StartShift('cashier1'));
      await waitForState(bloc, (s) => s.status == ShiftStatus.active);

      bloc.add(const EndShift());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.ended &&
              s.shift?.endedAt != null),
        ]),
      );
    });

    test('should force-logout when no active shift instead of failing', () async {
      bloc.add(const EndShift());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.ended &&
              s.shift == null &&
              s.failure == null),
        ]),
      );
    });

    test('should ignore EndShift queued while StartShift is loading', () async {
      bloc.add(const StartShift('cashier1'));
      bloc.add(const EndShift());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) => s.status == ShiftStatus.active),
        ]),
      );
    });

    test('should end cleanly when no active shift after a failed start', () async {
      repository.getActiveShiftFails = true;
      bloc.add(const StartShift('cashier1'));
      await waitForState(bloc, (s) => s.status == ShiftStatus.error);

      repository.getActiveShiftFails = false;
      bloc.add(const EndShift());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.ended &&
              s.shift == null &&
              s.failure == null),
        ]),
      );
    });
  });

  group('orphan recovery', () {
    test('should recover orphan shift when starting new shift', () async {
      final orphan = ShiftEntity(
        id: 'orphan-id',
        username: 'cashier1',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repository.save(orphan);

      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.orphanRecovered == true),
        ]),
      );
    });

    test('should reset orphanRecovered on next clean start', () async {
      final orphan = ShiftEntity(
        id: 'orphan-id',
        username: 'cashier1',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repository.save(orphan);

      bloc.add(const StartShift('cashier1'));
      await waitForState(bloc, (s) => s.status == ShiftStatus.active);
      expect(bloc.state.orphanRecovered, isTrue);

      bloc.add(const EndShift());
      await waitForState(bloc, (s) => s.status == ShiftStatus.ended);

      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.loading &&
              s.orphanRecovered == false),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.orphanRecovered == false),
        ]),
      );
    });

    test('should emit error and not create shift when orphan close save fails', () async {
      final orphan = ShiftEntity(
        id: 'orphan-id',
        username: 'cashier1',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repository.save(orphan);
      repository.saveFails = true;

      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.error &&
              s.shift == null &&
              s.failure is DatabaseFailure),
        ]),
      );
    });

    test('should not leak orphanRecovered when new shift save fails after recovery', () async {
      final orphan = ShiftEntity(
        id: 'orphan-id',
        username: 'cashier1',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repository.save(orphan);
      repository.failSaveOnCall = 3;

      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.error &&
              s.orphanRecovered == false &&
              s.failure is DatabaseFailure),
        ]),
      );
    });

    test('should start cleanly on retry after new shift save failure', () async {
      final orphan = ShiftEntity(
        id: 'orphan-id',
        username: 'cashier1',
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repository.save(orphan);
      repository.failSaveOnCall = 3;

      bloc.add(const StartShift('cashier1'));
      await waitForState(bloc, (s) => s.status == ShiftStatus.error);

      repository.failSaveOnCall = -1;
      bloc.add(const StartShift('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.orphanRecovered == false),
        ]),
      );
    });
  });

  group('repository failure', () {
    test('should handle getActiveShift failure on StartShift', () async {
      final failingBloc = ShiftBloc(repository: FailingFakeShiftsRepository());

      failingBloc.add(const StartShift('cashier1'));

      await expectLater(
        failingBloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.error &&
              s.failure is DatabaseFailure),
        ]),
      );

      failingBloc.close();
    });
  });
}
