import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

enum StationBlocStatus { initial, loading, ready, error }

class StationState {
  final StationBlocStatus status;
  final List<StationEntity> stations;
  final SessionRecordEntity? lastCompletedSession;
  final Failure? failure;

  const StationState({
    this.status = StationBlocStatus.initial,
    this.stations = const [],
    this.lastCompletedSession,
    this.failure,
  });

  StationState copyWith({
    StationBlocStatus? status,
    List<StationEntity>? stations,
    SessionRecordEntity? lastCompletedSession,
    bool clearLastCompletedSession = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return StationState(
      status: status ?? this.status,
      stations: stations ?? this.stations,
      lastCompletedSession: clearLastCompletedSession
          ? null
          : (lastCompletedSession ?? this.lastCompletedSession),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          stations == other.stations &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, stations, failure);
}
