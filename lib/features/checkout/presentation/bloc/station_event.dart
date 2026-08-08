enum PricingTier { normal, multi }

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
