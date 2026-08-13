import 'dart:async';

import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';

/// Periodically converts fixed-duration station sessions that ran past their
/// booked duration into open sessions (billing continues per hour).
///
/// A station qualifies when it is [StationStatus.active], uses a fixed
/// duration, and elapsed time exceeds `fixedDurationMinutes + gracePeriod`.
class AutoConversionService {
  final StationBloc _stationBloc;
  final Duration checkInterval;
  final Duration gracePeriod;
  final DateTime Function() _now;

  Timer? _timer;

  AutoConversionService({
    required StationBloc stationBloc,
    this.checkInterval = const Duration(seconds: 30),
    this.gracePeriod = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _stationBloc = stationBloc,
       _now = now ?? DateTime.now;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) => _check());
    _check();
  }

  void _check() {
    final now = _now();
    for (final station in _stationBloc.state.stations) {
      if (station.status != StationStatus.active || !station.isFixedDuration) {
        continue;
      }
      final start = station.sessionStartTime;
      final fixedMinutes = station.fixedDurationMinutes;
      if (start == null || fixedMinutes == null) continue;
      final elapsed = now.difference(start);
      if (elapsed >= Duration(minutes: fixedMinutes) + gracePeriod) {
        _stationBloc.add(ConvertToOpenSession(stationId: station.id));
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
