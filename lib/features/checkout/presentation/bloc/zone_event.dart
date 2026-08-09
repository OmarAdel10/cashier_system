import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';

sealed class ZoneEvent {
  const ZoneEvent();
}

class LoadZones extends ZoneEvent {
  const LoadZones();
}

class SaveZone extends ZoneEvent {
  final ZoneEntity zone;

  const SaveZone({required this.zone});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SaveZone && zone == other.zone;
  @override
  int get hashCode => zone.hashCode;
}

class DeleteZone extends ZoneEvent {
  final String zoneId;

  const DeleteZone({required this.zoneId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeleteZone && zoneId == other.zoneId;
  @override
  int get hashCode => zoneId.hashCode;
}
