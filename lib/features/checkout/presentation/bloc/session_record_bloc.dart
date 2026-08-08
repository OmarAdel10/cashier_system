import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/features/checkout/domain/repositories/i_session_record_repository.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/session_record_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/session_record_state.dart';

class SessionRecordBloc extends Bloc<SessionRecordEvent, SessionRecordState> {
  final ISessionRecordRepository _repository;
  final int _limit;

  SessionRecordBloc({
    required ISessionRecordRepository repository,
    int limit = 100,
  }) : _repository = repository,
       _limit = limit,
       super(const SessionRecordState()) {
    on<LoadSessionRecords>(_onLoad);
    on<CreateSessionRecord>(_onCreate);
    on<DeleteSessionRecord>(_onDelete);
  }

  Future<void> _onLoad(
    LoadSessionRecords event,
    Emitter<SessionRecordState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SessionRecordBlocStatus.loading,
        clearFailure: true,
      ),
    );
    final result = await _repository.getSessionRecords(limit: event.limit);
    result.fold(
      (failure) => emit(
        state.copyWith(status: SessionRecordBlocStatus.error, failure: failure),
      ),
      (records) => emit(
        state.copyWith(status: SessionRecordBlocStatus.ready, records: records),
      ),
    );
  }

  Future<void> _onCreate(
    CreateSessionRecord event,
    Emitter<SessionRecordState> emit,
  ) async {
    final saveResult = await _repository.saveSessionRecord(event.record);
    final failure = saveResult.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(failure: failure));
      return;
    }
    final records = await _repository.getSessionRecords(limit: _limit);
    records.fold(
      (f) => emit(
        state.copyWith(status: SessionRecordBlocStatus.error, failure: f),
      ),
      (updated) => emit(
        state.copyWith(status: SessionRecordBlocStatus.ready, records: updated),
      ),
    );
  }

  Future<void> _onDelete(
    DeleteSessionRecord event,
    Emitter<SessionRecordState> emit,
  ) async {
    final result = await _repository.deleteSessionRecord(event.id);
    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      emit(
        state.copyWith(
          records: state.records
              .where((record) => record.id != event.id)
              .toList(),
        ),
      );
    });
  }
}
