import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

/// One printer-target route for a fired round: the lines that belong to
/// [category] should be sent to the configured [printerName].
class TicketRoute {
  final PrepCategory category;
  final List<TableOrderLine> lines;
  final String printerName;

  const TicketRoute({
    required this.category,
    required this.lines,
    required this.printerName,
  });
}

/// Splits a round's lines into per-category printer routes.
///
/// Routing rules (mirror the Tickets settings section):
/// - `food` -> kitchen printer, only when `kitchenTicketsEnabled`
/// - `beverage` -> bar printer, only when `barTicketsEnabled`
/// - `shisha` -> shisha printer, only when `shishaTicketsEnabled`
/// - `general` has no ticket printer and is never routed
/// A category is skipped when its printer name is null/blank.
List<TicketRoute> routeTickets({
  required AppSettingsEntity settings,
  required List<TableOrderLine> lines,
}) {
  final food = lines.where((l) => l.prepCategory == PrepCategory.food).toList();
  final beverage = lines
      .where((l) => l.prepCategory == PrepCategory.beverage)
      .toList();
  final shisha = lines
      .where((l) => l.prepCategory == PrepCategory.shisha)
      .toList();

  final routes = <TicketRoute>[];
  _addRoute(
    routes,
    enabled: settings.kitchenTicketsEnabled,
    printerName: settings.kitchenPrinterName,
    category: PrepCategory.food,
    lines: food,
  );
  _addRoute(
    routes,
    enabled: settings.barTicketsEnabled,
    printerName: settings.barPrinterName,
    category: PrepCategory.beverage,
    lines: beverage,
  );
  _addRoute(
    routes,
    enabled: settings.shishaTicketsEnabled,
    printerName: settings.shishaPrinterName,
    category: PrepCategory.shisha,
    lines: shisha,
  );
  return routes;
}

void _addRoute(
  List<TicketRoute> routes, {
  required bool enabled,
  required String? printerName,
  required PrepCategory category,
  required List<TableOrderLine> lines,
}) {
  if (!enabled || lines.isEmpty) return;
  final printer = printerName?.trim() ?? '';
  if (printer.isEmpty) return;
  routes.add(
    TicketRoute(category: category, lines: lines, printerName: printer),
  );
}
