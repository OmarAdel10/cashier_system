import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/core/printing/ticket_print_helper.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/ticket_routing.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  final round = TableRoundEntity(
    id: 'RND-2026-08-09 14:30:00.000-t1',
    tableId: 't1',
    roundNumber: 2,
    firedAt: DateTime(2026, 8, 9, 14, 30),
    lines: const [
      TableOrderLine(
        name: 'Koshary',
        barcode: 'K1',
        quantity: 2,
        unitPricePiastres: 1000,
        prepCategory: PrepCategory.food,
      ),
    ],
  );

  const table = TableEntity(
    id: 't1',
    name: 'T1',
    zoneId: 'Z-DINE',
    capacity: 4,
  );

  const route = TicketRoute(
    category: PrepCategory.food,
    lines: [
      TableOrderLine(
        name: 'Koshary',
        barcode: 'K1',
        quantity: 2,
        unitPricePiastres: 1000,
        prepCategory: PrepCategory.food,
      ),
    ],
    printerName: 'KitchenPrinter',
  );

  group('buildTicketPayload', () {
    test('carries printer, venue and table/zone/round context', () {
      final payload = buildTicketPayload(
        route: route,
        round: round,
        table: table,
        zoneName: 'Main Hall',
        settings: const AppSettingsEntity(
          languageCode: 'en',
          storeName: 'Cafe X',
          storeAddress: 'Main St',
          storePhoneNumber: '0100',
        ),
      );

      expect(payload['printer_name'], 'KitchenPrinter');
      expect(payload['store_name'], 'Cafe X');
      expect(payload['store_address'], 'Main St');
      expect(payload['store_phone'], '0100');
      expect(payload['is_rtl'], false);
      expect(payload['table_name'], 'T1');
      expect(payload['zone_name'], 'Main Hall');
      expect(payload['round_number'], 2);
      expect(payload['order_number'], round.id);
      expect(payload['category'], 'food');
      expect(payload['created_at'], round.firedAt.toIso8601String());
      final items = payload['items'] as List<dynamic>;
      expect(items.length, 1);
      expect(items.single['name'], 'Koshary');
      expect(items.single['quantity'], 2);
    });

    test('carries no prices, totals or tax fields', () {
      final payload = buildTicketPayload(
        route: route,
        round: round,
        table: table,
        zoneName: '',
        settings: const AppSettingsEntity(),
      );

      expect(payload.containsKey('unit_price_piastres'), isFalse);
      expect(payload.containsKey('total_piastres'), isFalse);
      expect(payload.containsKey('subtotal_piastres'), isFalse);
      expect(payload.containsKey('discount_piastres'), isFalse);
      expect(payload.containsKey('tax_piastres'), isFalse);
      expect(payload.containsKey('tax_percent'), isFalse);
      final items = payload['items'] as List<dynamic>;
      expect(items.single.containsKey('price'), isFalse);
      expect(items.single.containsKey('total'), isFalse);
    });

    test('multiple lines each become a quantity x name item', () {
      final multiRoute = TicketRoute(
        category: PrepCategory.beverage,
        lines: const [
          TableOrderLine(
            name: 'Cola',
            barcode: 'C1',
            quantity: 3,
            unitPricePiastres: 500,
            prepCategory: PrepCategory.beverage,
          ),
          TableOrderLine(
            name: 'Tea',
            barcode: 'T1',
            quantity: 1,
            unitPricePiastres: 400,
            prepCategory: PrepCategory.beverage,
          ),
        ],
        printerName: 'BarPrinter',
      );
      final payload = buildTicketPayload(
        route: multiRoute,
        round: round,
        table: table,
        zoneName: '',
        settings: const AppSettingsEntity(),
      );

      final items = payload['items'] as List<dynamic>;
      expect(items.length, 2);
      expect(items[0]['name'], 'Cola');
      expect(items[0]['quantity'], 3);
      expect(items[1]['name'], 'Tea');
      expect(items[1]['quantity'], 1);
    });
  });
}
