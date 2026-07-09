import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/cart_item_entity.dart';

void main() {
  group('CartItemEntity', () {
    test('should create with default quantity of 1', () {
      final item = CartItemEntity(
        barcode: '123',
        name: 'Test',
        unitPricePiastres: 1500,
      );
      expect(item.quantity, 1);
    });

    test('should compute totalPiastres correctly', () {
      final item = CartItemEntity(
        barcode: '123',
        name: 'Test',
        quantity: 3,
        unitPricePiastres: 1500,
      );
      expect(item.totalPiastres, 4500);
    });

    test('copyWith should override specified fields', () {
      final item = CartItemEntity(
        barcode: '123', name: 'Test', quantity: 1, unitPricePiastres: 1000,
      );
      final copy = item.copyWith(quantity: 5);
      expect(copy.quantity, 5);
      expect(copy.barcode, '123');
    });

    test('equality should work correctly', () {
      final a = CartItemEntity(
        barcode: '123', name: 'Test', quantity: 1, unitPricePiastres: 1000,
      );
      final b = CartItemEntity(
        barcode: '123', name: 'Test', quantity: 1, unitPricePiastres: 1000,
      );
      expect(a, b);
    });
  });
}
