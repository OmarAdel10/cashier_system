import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_state.dart';
import '../../helpers/fake_shifts_repository.dart';

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
}
