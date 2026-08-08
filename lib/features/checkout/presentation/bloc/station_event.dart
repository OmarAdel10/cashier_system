import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

sealed class StationEvent {
  const StationEvent();
}

class LoadStations extends StationEvent {
  const LoadStations();
}

class StartSession extends StationEvent {
  final String stationId;
  final PricingTier tier;
  final bool isFixedDuration;
  final int? fixedDurationMinutes;

  const StartSession({
    required this.stationId,
    required this.tier,
    this.isFixedDuration = false,
    this.fixedDurationMinutes,
  });
}

class EndSession extends StationEvent {
  final String stationId;

  const EndSession({required this.stationId});
}

class ConvertToOpenSession extends StationEvent {
  final String stationId;

  const ConvertToOpenSession({required this.stationId});
}

class SaveStation extends StationEvent {
  final StationEntity station;

  const SaveStation({required this.station});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveStation && station == other.station;
  @override
  int get hashCode => station.hashCode;
}

class DeleteStation extends StationEvent {
  final String stationId;

  const DeleteStation({required this.stationId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteStation && stationId == other.stationId;
  @override
  int get hashCode => stationId.hashCode;
}
