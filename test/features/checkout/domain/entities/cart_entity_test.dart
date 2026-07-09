import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/cart_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/cart_item_entity.dart';

void main() {
  group('CartEntity', () {
    test('create should generate 15-char transactionId', () {
      final cart = CartEntity.create();
      expect(cart.transactionId.length, 15);
      expect(cart.items, isEmpty);
    });

    test('create should generate unique transactionIds', () {
      final a = CartEntity.create();
      final b = CartEntity.create();
      expect(a.transactionId, isNot(b.transactionId));
    });

    test('subtotalPiastres should sum item totals', () {
      final cart = CartEntity(
        items: [
          CartItemEntity(barcode: '1', name: 'A', quantity: 2, unitPricePiastres: 1000),
          CartItemEntity(barcode: '2', name: 'B', quantity: 1, unitPricePiastres: 500),
        ],
        transactionId: '123456789012345',
      );
      expect(cart.subtotalPiastres, 2500);
    });

    test('isEmpty should return true for empty cart', () {
      final cart = CartEntity(items: const [], transactionId: '123456789012345');
      expect(cart.isEmpty, isTrue);
    });
  });
}
