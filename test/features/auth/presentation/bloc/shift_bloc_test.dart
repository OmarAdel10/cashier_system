import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_state.dart';
import '../../helpers/fake_shifts_repository.dart';
import '../../../../helpers/fake_license_engine.dart';

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
}

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

void main() {
  late ShiftBloc bloc;
  late FakeShiftsRepository repository;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    repository = FakeShiftsRepository();
    bloc = ShiftBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

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
  });

  group('EndShift', () {
    test('should end active shift', () async {
      bloc.add(const StartShift('cashier1'));
      await bloc.stream.first;
      await bloc.stream.first;

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

    test('should fail when no active shift', () async {
      bloc.add(const EndShift());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.error &&
              s.failure is DatabaseFailure),
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
  });

  group('IncrementShiftOrderCount', () {
    test('should increment orderCount', () async {
      bloc.add(const StartShift('cashier1'));
      await bloc.stream.first;
      await bloc.stream.first;

      final shiftId = bloc.state.shift!.id;
      bloc.add(IncrementShiftOrderCount(shiftId));

      await expectLater(
        bloc.stream,
        emits(predicate<ShiftState>((s) =>
            s.shift?.orderCount == 2)),
      );
    });

    test('should ignore if shiftId does not match', () async {
      bloc.add(const StartShift('cashier1'));
      await bloc.stream.first;
      await bloc.stream.first;

      final before = bloc.state.shift!.orderCount;
      bloc.add(const IncrementShiftOrderCount('nonexistent-id'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.shift!.orderCount, before);
    });

    test('should ignore when no active shift', () async {
      bloc.add(const IncrementShiftOrderCount('any-id'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.status, ShiftStatus.initial);
    });
  });

  group('repository failure', () {
    test('should handle getActiveShift failure on StartShift', () async {
      final failingBloc = ShiftBloc(repository: FailingFakeShiftsRepository());
      HydratedBloc.storage = _MockStorage();

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

  group('license verification', () {
    test('should block shift start when license fails', () async {
      final failingLicense = FakeLicenseEngine(quickVerifyResult: false);
      final failingBloc = ShiftBloc(
        repository: repository,
        licenseEngine: failingLicense,
      );
      HydratedBloc.storage = _MockStorage();

      failingBloc.add(const StartShift('cashier1'));

      await expectLater(
        failingBloc.stream,
        emits(
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.error &&
              s.failure is DatabaseFailure),
        ),
      );

      failingBloc.close();
    });

    test('should allow shift start when license passes', () async {
      final passingLicense = FakeLicenseEngine(quickVerifyResult: true);
      final passingBloc = ShiftBloc(
        repository: repository,
        licenseEngine: passingLicense,
      );
      HydratedBloc.storage = _MockStorage();

      passingBloc.add(const StartShift('cashier1'));

      await expectLater(
        passingBloc.stream,
        emitsInOrder([
          predicate<ShiftState>((s) => s.status == ShiftStatus.loading),
          predicate<ShiftState>((s) =>
              s.status == ShiftStatus.active &&
              s.shift?.username == 'cashier1'),
        ]),
      );

      passingBloc.close();
    });
  });
}
