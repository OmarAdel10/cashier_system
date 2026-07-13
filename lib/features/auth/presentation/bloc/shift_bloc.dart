import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/shift_entity.dart';
import '../../domain/repositories/i_shifts_repository.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final IShiftsRepository _repository;

  ShiftBloc({required IShiftsRepository repository})
      : _repository = repository,
        super(const ShiftState()) {
    on<StartShift>(_onStartShift);
    on<EndShift>(_onEndShift);
  }

  Future<void> _onStartShift(
      StartShift event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(status: ShiftStatus.loading, clearFailure: true));

    final orphanResult = await _repository.getActiveShift(event.username);
    await orphanResult.fold(
      (failure) async => emit(state.copyWith(status: ShiftStatus.error, failure: failure)),
      (orphan) async {
        bool recovered = false;
        if (orphan != null) {
          final closed = orphan.copyWith(endedAt: DateTime.now());
          await _repository.update(closed);
          recovered = true;
        }
        final newShift = ShiftEntity(
          id: _generateId(),
          username: event.username,
          startedAt: DateTime.now(),
        );
        final saveResult = await _repository.save(newShift);
        saveResult.fold(
          (failure) => emit(state.copyWith(status: ShiftStatus.error, failure: failure)),
          (_) => emit(state.copyWith(
            status: ShiftStatus.active,
            shift: newShift,
            orphanRecovered: recovered,
          )),
        );
      },
    );
  }

  Future<void> _onEndShift(
      EndShift event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(status: ShiftStatus.loading));
    if (state.shift == null) {
      emit(state.copyWith(
        status: ShiftStatus.error,
        failure: const DatabaseFailure('No active shift to end'),
      ));
      return;
    }
    final closed = state.shift!.copyWith(endedAt: DateTime.now());
    final result = await _repository.update(closed);
    result.fold(
      (failure) => emit(state.copyWith(status: ShiftStatus.error, failure: failure)),
      (_) => emit(state.copyWith(status: ShiftStatus.ended, shift: closed)),
    );
  }

  String _generateId() {
    final now = DateTime.now();
    final r = (_random.nextInt(1 << 32)).toRadixString(16).padLeft(8, '0');
    return '${now.microsecondsSinceEpoch.toRadixString(16)}-$r';
  }

  static final _random = _SimpleRandom();
}

class _SimpleRandom {
  int _seed = DateTime.now().microsecondsSinceEpoch;

  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }
}
