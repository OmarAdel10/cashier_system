import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/licensing/domain/enums/license_status.dart';
import '../../../../core/licensing/engine/license_engine.dart';
import '../../domain/entities/shift_entity.dart';
import '../../domain/repositories/i_shifts_repository.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final IShiftsRepository _repository;
  final LicenseEngine? _licenseEngine;

  ShiftBloc({
    required IShiftsRepository repository,
    LicenseEngine? licenseEngine,
  }) : _repository = repository,
       _licenseEngine = licenseEngine,
       super(const ShiftState()) {
    on<StartShift>(_onStartShift);
    on<EndShift>(_onEndShift);
    on<IncrementShiftOrderCount>(_onIncrementShiftOrderCount);
  }

  Future<void> _onStartShift(StartShift event, Emitter<ShiftState> emit) async {
    if (state.status == ShiftStatus.loading ||
        state.status == ShiftStatus.active)
      return;

    if (_licenseEngine != null) {
      final status = await _licenseEngine.verifyLicense();
      if (status != LicenseStatus.valid) {
        emit(
          state.copyWith(
            status: ShiftStatus.error,
            failure: const DatabaseFailure(
              'License verification failed. Cannot start shift.',
            ),
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        status: ShiftStatus.loading,
        orphanRecovered: false,
        clearFailure: true,
        clearShift: true,
      ),
    );
    Failure? failure;
    bool recovered = false;
    while (true) {
      final orphanResult = await _repository.getActiveShift(event.username);
      orphanResult.fold((f) => failure = f, (_) {});
      if (failure != null) {
        emit(state.copyWith(status: ShiftStatus.error, failure: failure));
        return;
      }
      final orphan = orphanResult.fold((_) => null, (o) => o);
      if (orphan == null) break;
      final closed = orphan.copyWith(endedAt: DateTime.now());
      final updateResult = await _repository.save(closed);
      Failure? updateFailure;
      updateResult.fold((f) => updateFailure = f, (_) {});
      if (updateFailure != null) {
        emit(state.copyWith(status: ShiftStatus.error, failure: updateFailure));
        return;
      }
      recovered = true;
    }
    final newShift = ShiftEntity(
      id: _generateId(),
      username: event.username,
      startedAt: DateTime.now(),
    );
    final saveResult = await _repository.save(newShift);
    saveResult.fold(
      (failure) =>
          emit(state.copyWith(status: ShiftStatus.error, failure: failure)),
      (_) => emit(
        state.copyWith(
          status: ShiftStatus.active,
          shift: newShift,
          orphanRecovered: recovered,
        ),
      ),
    );
  }

  Future<void> _onEndShift(EndShift event, Emitter<ShiftState> emit) async {
    if (state.status == ShiftStatus.loading) return;
    emit(state.copyWith(status: ShiftStatus.loading, clearFailure: true));
    if (state.shift == null) {
      emit(state.copyWith(status: ShiftStatus.ended, clearShift: true));
      return;
    }
    final closed = state.shift!.copyWith(endedAt: DateTime.now());
    final result = await _repository.save(closed);
    result.fold(
      (failure) =>
          emit(state.copyWith(status: ShiftStatus.error, failure: failure)),
      (_) => emit(state.copyWith(status: ShiftStatus.ended, shift: closed)),
    );
  }

  Future<void> _onIncrementShiftOrderCount(
    IncrementShiftOrderCount event,
    Emitter<ShiftState> emit,
  ) async {
    if (state.status != ShiftStatus.active ||
        state.shift == null ||
        state.shift!.id != event.shiftId)
      return;
    final updated = state.shift!.copyWith(
      orderCount: state.shift!.orderCount + 1,
    );
    final result = await _repository.save(updated);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(state.copyWith(shift: updated)),
    );
  }

  String _generateId() => const Uuid().v4();
}
