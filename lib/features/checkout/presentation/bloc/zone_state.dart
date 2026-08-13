import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';

enum ZoneBlocStatus { initial, loading, ready, error }

class ZoneState {
  final ZoneBlocStatus status;
  final List<ZoneEntity> zones;
  final Failure? failure;

  const ZoneState({
    this.status = ZoneBlocStatus.initial,
    this.zones = const [],
    this.failure,
  });

  ZoneState copyWith({
    ZoneBlocStatus? status,
    List<ZoneEntity>? zones,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ZoneState(
      status: status ?? this.status,
      zones: zones ?? this.zones,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          zones == other.zones &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, zones, failure);
}
