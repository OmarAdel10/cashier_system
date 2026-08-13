import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/core/error/failure.dart';
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
    on<AddStationAddon>(_onAddStationAddon);
    on<SetStationAddons>(_onSetStationAddons);
    on<SaveStation>(_onSaveStation);
    on<DeleteStation>(_onDeleteStation);
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
    final station = _findStation(event.stationId);
    if (station == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Station not found: ${event.stationId}'),
        ),
      );
      return;
    }

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
    final station = _findStation(event.stationId);
    if (station == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Station not found: ${event.stationId}'),
        ),
      );
      return;
    }

    final record = station.sessionStartTime == null
        ? null
        : _buildSessionRecord(station);
    final updated = station.copyWith(
      status: StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: null,
      sessionTier: null,
      addonLines: const [],
    );

    final result = await _repository.updateStationStatus(
      event.stationId,
      StationStatus.available,
      sessionStartTime: null,
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: null,
      sessionTier: null,
      addonLines: const [],
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

  Future<void> _onAddStationAddon(
    AddStationAddon event,
    Emitter<StationState> emit,
  ) async {
    final station = _findStation(event.stationId);
    if (station == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Station not found: ${event.stationId}'),
        ),
      );
      return;
    }

    if (station.status != StationStatus.active &&
        station.status != StationStatus.overtime) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Cannot add addon to inactive station'),
        ),
      );
      return;
    }

    if (event.line.quantity < 1 || event.line.unitPricePiastres < 0) {
      emit(
        state.copyWith(failure: DatabaseFailure('Invalid addon line values')),
      );
      return;
    }

    final updatedAddonLines = [...station.addonLines, event.line];
    final updated = station.copyWith(addonLines: updatedAddonLines);

    final result = await _repository.updateStationStatus(
      event.stationId,
      station.status,
      addonLines: updatedAddonLines,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(state.copyWith(stations: stations, clearFailure: true));
    });
  }

  Future<void> _onSetStationAddons(
    SetStationAddons event,
    Emitter<StationState> emit,
  ) async {
    final station = _findStation(event.stationId);
    if (station == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Station not found: ${event.stationId}'),
        ),
      );
      return;
    }

    if (station.status != StationStatus.active &&
        station.status != StationStatus.overtime) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Cannot add addon to inactive station'),
        ),
      );
      return;
    }

    final invalid = event.lines.any(
      (l) => l.quantity < 1 || l.unitPricePiastres < 0,
    );
    if (invalid) {
      emit(
        state.copyWith(failure: DatabaseFailure('Invalid addon line values')),
      );
      return;
    }

    final updated = station.copyWith(addonLines: event.lines);

    final result = await _repository.updateStationStatus(
      event.stationId,
      station.status,
      addonLines: event.lines,
    );

    result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
      final stations = state.stations
          .map((s) => s.id == event.stationId ? updated : s)
          .toList();
      emit(state.copyWith(stations: stations, clearFailure: true));
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
    final addonTotal = station.addonTotalPiastres;

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
      subtotalPiastres: charged + addonTotal,
      totalPiastres: charged + addonTotal,
      taxPercent: 0,
      discountPercent: 0,
      addonLines: station.addonLines,
    );
  }

  Future<void> _onConvertToOpenSession(
    ConvertToOpenSession event,
    Emitter<StationState> emit,
  ) async {
    final station = _findStation(event.stationId);
    if (station == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure('Station not found: ${event.stationId}'),
        ),
      );
      return;
    }
    final start = station.sessionStartTime;
    if (start == null) {
      emit(
        state.copyWith(
          failure: DatabaseFailure(
            'Station has no active session: ${event.stationId}',
          ),
        ),
      );
      return;
    }

    final updated = station.copyWith(
      isFixedDuration: false,
      fixedDurationMinutes: null,
      overtimeStartMinutes: _now().difference(start).inMinutes,
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

  StationEntity? _findStation(String stationId) {
    for (final station in state.stations) {
      if (station.id == stationId) return station;
    }
    return null;
  }

  Future<void> _onSaveStation(
    SaveStation event,
    Emitter<StationState> emit,
  ) async {
    final result = await _repository.saveStation(event.station);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          stations: [
            event.station,
            ...state.stations.where((s) => s.id != event.station.id),
          ],
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onDeleteStation(
    DeleteStation event,
    Emitter<StationState> emit,
  ) async {
    final result = await _repository.deleteStation(event.stationId);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          stations: state.stations
              .where((s) => s.id != event.stationId)
              .toList(),
          clearFailure: true,
        ),
      ),
    );
  }
}
