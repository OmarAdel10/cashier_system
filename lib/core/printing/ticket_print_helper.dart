import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/ticket_routing.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

/// Builds the ticket print payload for one routed category.
///
/// The ticket carries venue info, table/zone/round, order number and
/// qty x name lines only — no prices, totals or tax (kitchen ticket layout).
Map<String, dynamic> buildTicketPayload({
  required TicketRoute route,
  required TableRoundEntity round,
  required TableEntity table,
  required String zoneName,
  required AppSettingsEntity settings,
}) {
  return {
    'printer_name': route.printerName,
    'store_name': settings.storeName,
    'store_address': settings.storeAddress,
    'store_phone': settings.storePhoneNumber,
    'is_rtl': settings.isRtl,
    'table_name': table.name,
    'zone_name': zoneName,
    'round_number': round.roundNumber,
    'order_number': round.id,
    'category': route.category.name,
    'created_at': round.firedAt.toIso8601String(),
    'items': [
      for (final line in route.lines)
        {'name': line.name, 'quantity': line.quantity},
    ],
  };
}
