import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/helpers/ticket_routing.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  const foodLine = TableOrderLine(
    name: 'Koshary',
    barcode: 'K1',
    quantity: 2,
    unitPricePiastres: 1000,
    prepCategory: PrepCategory.food,
  );
  const beverageLine = TableOrderLine(
    name: 'Cola',
    barcode: 'C1',
    quantity: 1,
    unitPricePiastres: 500,
    prepCategory: PrepCategory.beverage,
  );
  const shishaLine = TableOrderLine(
    name: 'Double Apple',
    barcode: 'S1',
    quantity: 1,
    unitPricePiastres: 1500,
    prepCategory: PrepCategory.shisha,
  );
  const generalLine = TableOrderLine(
    name: 'Charger',
    barcode: 'G1',
    quantity: 1,
    unitPricePiastres: 2000,
    prepCategory: PrepCategory.general,
  );

  final enabled = AppSettingsEntity(
    businessType: 'cafe',
    kitchenTicketsEnabled: true,
    kitchenPrinterName: 'KitchenPrinter',
    barTicketsEnabled: true,
    barPrinterName: 'BarPrinter',
    shishaTicketsEnabled: true,
    shishaPrinterName: 'ShishaPrinter',
  );

  group('routeTickets', () {
    test('splits lines by prepCategory into per-printer routes', () {
      final routes = routeTickets(
        settings: enabled,
        lines: [foodLine, beverageLine, shishaLine],
      );

      expect(routes.length, 3);
      final kitchen = routes.singleWhere(
        (r) => r.printerName == 'KitchenPrinter',
      );
      expect(kitchen.category, PrepCategory.food);
      expect(kitchen.lines, [foodLine]);
      final bar = routes.singleWhere((r) => r.printerName == 'BarPrinter');
      expect(bar.category, PrepCategory.beverage);
      expect(bar.lines, [beverageLine]);
      final shisha = routes.singleWhere(
        (r) => r.printerName == 'ShishaPrinter',
      );
      expect(shisha.category, PrepCategory.shisha);
      expect(shisha.lines, [shishaLine]);
    });

    test('groups multiple lines of same category into one route', () {
      const foodLine2 = TableOrderLine(
        name: 'Pizza',
        barcode: 'P1',
        quantity: 1,
        unitPricePiastres: 2000,
        prepCategory: PrepCategory.food,
      );
      final routes = routeTickets(
        settings: enabled,
        lines: [foodLine, foodLine2],
      );

      expect(routes.length, 1);
      expect(routes.single.lines, [foodLine, foodLine2]);
    });

    test('skips disabled categories', () {
      final routes = routeTickets(
        settings: enabled.copyWith(
          kitchenTicketsEnabled: false,
          shishaTicketsEnabled: false,
        ),
        lines: [foodLine, beverageLine, shishaLine],
      );

      expect(routes.length, 1);
      expect(routes.single.printerName, 'BarPrinter');
      expect(routes.single.lines, [beverageLine]);
    });

    test('skips categories without a configured printer', () {
      final routes = routeTickets(
        // copyWith cannot null out fields; build with bar printer unset.
        settings: const AppSettingsEntity(
          businessType: 'cafe',
          kitchenTicketsEnabled: true,
          kitchenPrinterName: 'KitchenPrinter',
          barTicketsEnabled: true,
          shishaTicketsEnabled: true,
          shishaPrinterName: 'ShishaPrinter',
        ),
        lines: [foodLine, beverageLine, shishaLine],
      );

      expect(routes.length, 2);
      expect(routes.map((r) => r.printerName), isNot(contains('BarPrinter')));
      expect(
        routes.map((r) => r.printerName),
        containsAll(['KitchenPrinter', 'ShishaPrinter']),
      );
    });

    test('skips empty printer names (whitespace)', () {
      final routes = routeTickets(
        settings: enabled.copyWith(kitchenPrinterName: '   '),
        lines: [foodLine, beverageLine],
      );

      expect(routes.length, 1);
      expect(routes.single.printerName, 'BarPrinter');
    });

    test('general category has no ticket route', () {
      final routes = routeTickets(
        settings: enabled,
        lines: [generalLine, foodLine],
      );

      expect(routes.length, 1);
      expect(routes.single.lines, [foodLine]);
    });

    test('empty lines produce no routes', () {
      final routes = routeTickets(settings: enabled, lines: const []);
      expect(routes, isEmpty);
    });
  });
}
