import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

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

class AddStationAddon extends StationEvent {
  final String stationId;
  final TableOrderLine line;

  const AddStationAddon({required this.stationId, required this.line});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddStationAddon &&
          stationId == other.stationId &&
          line == other.line;

  @override
  int get hashCode => Object.hash(stationId, line);
}

class SetStationAddons extends StationEvent {
  final String stationId;
  final List<TableOrderLine> lines;

  const SetStationAddons({required this.stationId, required this.lines});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetStationAddons &&
          stationId == other.stationId &&
          _listEquals(lines, other.lines);

  @override
  int get hashCode => Object.hash(stationId, Object.hashAll(lines));

  static bool _listEquals(List<TableOrderLine> a, List<TableOrderLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
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
