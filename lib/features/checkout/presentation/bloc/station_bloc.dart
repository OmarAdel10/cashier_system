import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_station_repository.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_state.dart';

class StationBloc extends Bloc<StationEvent, StationState> {
  final IStationRepository _repository;
  final DateTime Function() _now;

  StationBloc({
    required IStationRepository repository,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now,
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
      sessionStartTime: _now(),
      isFixedDuration: event.isFixedDuration,
      fixedDurationMinutes: event.fixedDurationMinutes,
      sessionTier: event.tier,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.active,
      sessionStartTime: updated.sessionStartTime,
      isFixedDuration: updated.isFixedDuration,
      fixedDurationMinutes: updated.fixedDurationMinutes,
      sessionTier: event.tier,
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

    final record = _buildSessionRecord(station);
    final updated = station.copyWith(
      status: StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: null,
      sessionTier: null,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
      sessionTier: null,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(
        state.copyWith(
          stations: stations,
          lastCompletedSession: record,
          clearFailure: true,
        ),
      );
    });
  }

  /// Composes the billing record for a completed session.
  ///
  /// Billing model: billed minutes are the booked fixed duration (or elapsed
  /// for open sessions); overtime minutes beyond the slot are charged on top.
  /// Subtotal is `max(minimum game cost, hourly rate * billed minutes)`.
  /// Discount/tax are 0 at record creation (applied at the charge step).
  SessionRecordEntity _buildSessionRecord(StationEntity station) {
    final now = _now();
    final start = station.sessionStartTime ?? now;
    final elapsed = now.difference(start).inMinutes < 1
        ? 1
        : now.difference(start).inMinutes;
    final fixed = station.fixedDurationMinutes;
    final tier = station.sessionTier ?? PricingTier.normal;
    final billedMinutes = station.isFixedDuration && fixed != null
        ? (fixed > elapsed ? fixed : elapsed)
        : elapsed;
    final hourlyRate = tier == PricingTier.multi
        ? station.multiHourlyRate
        : station.normalHourlyRate;
    final minimumGameCost = tier == PricingTier.multi
        ? station.minimumGameCostMulti
        : station.minimumGameCostNormal;

    final subtotal = ((hourlyRate / 60) * billedMinutes * 100).round();
    final charged = subtotal > minimumGameCost ? subtotal : minimumGameCost;

    return SessionRecordEntity(
      id: 'SES-${now.millisecondsSinceEpoch}-${station.id}',
      shiftId: '',
      stationId: station.id,
      stationName: station.name,
      parentCategory: station.parentCategory,
      tier: tier == PricingTier.multi ? SessionTier.multi : SessionTier.normal,
      startTime: start,
      endTime: now,
      durationMinutes: billedMinutes,
      wasFixedDuration: station.isFixedDuration,
      fixedDurationMinutes: fixed,
      hourlyRate: hourlyRate,
      minimumGameCost: minimumGameCost,
      subtotalPiastres: charged,
      totalPiastres: charged,
      taxPercent: 0,
      discountPercent: 0,
    );
  }

  Future<void> _onConvertToOpenSession(
    ConvertToOpenSession event,
    Emitter<StationState> emit,
  ) async {
    final station = state.stations.firstWhere((s) => s.id == event.stationId);

    final updated = station.copyWith(
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: _now()
          .difference(station.sessionStartTime!)
          .inMinutes,
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.active,
      sessionStartTime: station.sessionStartTime,
      isFixedDuration: false,
      fixedDurationMinutes: null,
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
