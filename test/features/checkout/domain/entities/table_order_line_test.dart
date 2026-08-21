import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

void main() {
  group('TableOrderLine', () {
    test('should default quantity 1 and prepCategory food', () {
      const line = TableOrderLine(name: 'Cola');

      expect(line.barcode, '');
      expect(line.quantity, 1);
      expect(line.unitPricePiastres, 0);
      expect(line.prepCategory, PrepCategory.food);
    });

    test('copyWith should update fields', () {
      const line = TableOrderLine(name: 'Cola', quantity: 1);

      final copy = line.copyWith(
        quantity: 3,
        prepCategory: PrepCategory.beverage,
      );

      expect(copy.quantity, 3);
      expect(copy.prepCategory, PrepCategory.beverage);
      expect(copy.name, 'Cola');
    });

    test('should respect equality', () {
      const a = TableOrderLine(
        name: 'Cola',
        quantity: 2,
        unitPricePiastres: 1500,
        prepCategory: PrepCategory.beverage,
      );
      const b = TableOrderLine(
        name: 'Cola',
        quantity: 2,
        unitPricePiastres: 1500,
        prepCategory: PrepCategory.beverage,
      );
      const c = TableOrderLine(name: 'Pepsi', quantity: 2);

      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
