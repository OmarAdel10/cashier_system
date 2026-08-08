import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

enum StationBlocStatus { initial, loading, ready, error }

class StationState {
  final StationBlocStatus status;
  final List<StationEntity> stations;
  final Failure? failure;

  const StationState({
    this.status = StationBlocStatus.initial,
    this.stations = const [],
    this.failure,
  });

  StationState copyWith({
    StationBlocStatus? status,
    List<StationEntity>? stations,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return StationState(
      status: status ?? this.status,
      stations: stations ?? this.stations,
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
