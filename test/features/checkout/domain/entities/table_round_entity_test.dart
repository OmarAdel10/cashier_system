import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

void main() {
  group('TableRoundEntity', () {
    const line1 = TableOrderLine(
      name: 'Chicken Sandwich',
      barcode: '1001',
      quantity: 2,
      unitPricePiastres: 7500,
      prepCategory: PrepCategory.food,
    );
    const line2 = TableOrderLine(
      name: 'Cola',
      barcode: '2002',
      quantity: 1,
      unitPricePiastres: 1500,
      prepCategory: PrepCategory.beverage,
    );

    test('should default to pendingKitchen status', () {
      final round = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: const [line1],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );

      expect(round.status, RoundStatus.pendingKitchen);
      expect(round.lines.length, 1);
    });

    test('copyWith should keep firedAt when not provided', () {
      final fired = DateTime(2026, 8, 9, 14, 30);
      final round = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: [line1],
        firedAt: fired,
      );

      final copy = round.copyWith(roundNumber: 2);

      expect(copy.firedAt, fired);
      expect(copy.status, RoundStatus.pendingKitchen);
    });

    test('copyWith should replace lines and update status', () {
      final round = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: [line1],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );

      final copy = round.copyWith(
        lines: [line1, line2],
        status: RoundStatus.served,
      );

      expect(copy.lines.length, 2);
      expect(copy.status, RoundStatus.served);
    });

    test('should respect deep equality on lines', () {
      final a = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: const [line1, line2],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );
      final b = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: const [line1, line2],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );
      final c = TableRoundEntity(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: const [line1],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );

      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
