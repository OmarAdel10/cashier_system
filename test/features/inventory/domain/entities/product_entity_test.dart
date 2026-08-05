import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('ProductEntity', () {
    group('defaults', () {
      test('should use default values when only required fields provided', () {
        const entity = ProductEntity(barcode: '123456789012', name: 'Test');

        expect(entity.price, 0.0);
        expect(entity.purchasePrice, 0.0);
        expect(entity.stock, 0);
        expect(entity.isQuickTile, false);
        expect(entity.tileColorHex, isNull);
      });
    });

    group('custom values', () {
      test('should store provided values', () {
        const entity = ProductEntity(
          barcode: '987654321098',
          name: 'Widget',
          price: 15.99,
          purchasePrice: 8.50,
          stock: 42,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );

        expect(entity.barcode, '987654321098');
        expect(entity.name, 'Widget');
        expect(entity.price, 15.99);
        expect(entity.purchasePrice, 8.50);
        expect(entity.stock, 42);
        expect(entity.isQuickTile, true);
        expect(entity.tileColorHex, '#10B981');
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        const original = ProductEntity(
          barcode: '123',
          name: 'Original',
          price: 10.0,
          purchasePrice: 4.5,
          stock: 5,
          isQuickTile: false,
        );

        final modified = original.copyWith(
          name: 'Updated',
          stock: 10,
          purchasePrice: 12.0,
        );

        expect(modified.barcode, '123');
        expect(modified.name, 'Updated');
        expect(modified.price, 10.0);
        expect(modified.purchasePrice, 12.0);
        expect(modified.stock, 10);
      });

      test('should keep original fields when not specified', () {
        const original = ProductEntity(
          barcode: '123',
          name: 'Original',
          price: 10.0,
          purchasePrice: 4.5,
          stock: 5,
        );

        final modified = original.copyWith();

        expect(modified.barcode, '123');
        expect(modified.name, 'Original');
        expect(modified.price, 10.0);
        expect(modified.purchasePrice, 4.5);
        expect(modified.stock, 5);
        expect(modified.isQuickTile, false);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        const a = ProductEntity(
          barcode: '123',
          name: 'Test',
          price: 10.0,
          purchasePrice: 4.5,
          stock: 5,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );
        const b = ProductEntity(
          barcode: '123',
          name: 'Test',
          price: 10.0,
          purchasePrice: 4.5,
          stock: 5,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('should not be equal when barcode differs', () {
        const a = ProductEntity(barcode: '123', name: 'A');
        const b = ProductEntity(barcode: '456', name: 'A');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when name differs', () {
        const a = ProductEntity(barcode: '123', name: 'A');
        const b = ProductEntity(barcode: '123', name: 'B');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when price differs', () {
        const a = ProductEntity(barcode: '123', name: 'A', price: 1.0);
        const b = ProductEntity(barcode: '123', name: 'A', price: 2.0);

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when purchasePrice differs', () {
        const a = ProductEntity(
          barcode: '123',
          name: 'A',
          price: 1.0,
          purchasePrice: 0.5,
        );
        const b = ProductEntity(
          barcode: '123',
          name: 'A',
          price: 1.0,
          purchasePrice: 1.5,
        );

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when stock differs', () {
        const a = ProductEntity(barcode: '123', name: 'A', stock: 1);
        const b = ProductEntity(barcode: '123', name: 'A', stock: 2);

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when isQuickTile differs', () {
        const a = ProductEntity(barcode: '123', name: 'A', isQuickTile: false);
        const b = ProductEntity(barcode: '123', name: 'A', isQuickTile: true);

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when tileColorHex differs', () {
        const a = ProductEntity(
          barcode: '123',
          name: 'A',
          tileColorHex: '#fff',
        );
        const b = ProductEntity(
          barcode: '123',
          name: 'A',
          tileColorHex: '#000',
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
