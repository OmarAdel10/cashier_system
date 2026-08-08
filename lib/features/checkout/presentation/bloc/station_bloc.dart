import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_station_repository.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_state.dart';

class StationBloc extends Bloc<StationEvent, StationState> {
  final IStationRepository _repository;

  StationBloc({required IStationRepository repository})
    : _repository = repository,
      super(const StationState()) {
    on<LoadStations>(_onLoadStations);
    on<StartSession>(_onStartSession);
    on<EndSession>(_onEndSession);
    on<ConvertToOpenSession>(_onConvertToOpenSession);
  }

  Future<void> _onLoadStations(
    LoadStations event,
    Emitter<StationState> emit,
  ) async {
    emit(state.copyWith(status: StationBlocStatus.loading, clearFailure: true));
    final result = await _repository.getStations();
    result.fold(
      (failure) => emit(
        state.copyWith(status: StationBlocStatus.error, failure: failure),
      ),
      (stations) => emit(
        state.copyWith(status: StationBlocStatus.ready, stations: stations),
      ),
    );
  }

  Future<void> _onStartSession(
    StartSession event,
    Emitter<StationState> emit,
  ) async {
    final station = state.stations.firstWhere(
      (s) => s.id == event.stationId,
      orElse: () => throw StateError('Station not found: ${event.stationId}'),
    );

    final updated = station.copyWith(
      status: StationStatus.active,
      sessionStartTime: DateTime.now(),
      isFixedDuration: event.isFixedDuration,
      fixedDurationMinutes: event.fixedDurationMinutes,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.active,
      sessionStartTime: updated.sessionStartTime,
      isFixedDuration: updated.isFixedDuration,
      fixedDurationMinutes: updated.fixedDurationMinutes,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(state.copyWith(stations: stations, clearFailure: true));
    });
  }

  Future<void> _onEndSession(
    EndSession event,
    Emitter<StationState> emit,
  ) async {
    final station = state.stations.firstWhere((s) => s.id == event.stationId);

    final updated = station.copyWith(
      status: StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: null,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(state.copyWith(stations: stations, clearFailure: true));
    });
  }

  Future<void> _onConvertToOpenSession(
    ConvertToOpenSession event,
    Emitter<StationState> emit,
  ) async {
    final station = state.stations.firstWhere((s) => s.id == event.stationId);

    final updated = station.copyWith(
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: DateTime.now()
          .difference(station.sessionStartTime!)
          .inMinutes,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.active,
      sessionStartTime: station.sessionStartTime,
      isFixedDuration: false,
      overtimeStartMinutes: updated.overtimeStartMinutes,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(state.copyWith(stations: stations, clearFailure: true));
    });
  }
}
