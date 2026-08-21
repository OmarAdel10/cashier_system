import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('ProductEntity', () {
    group('defaults', () {
      test('should use default values when only required fields provided', () {
        const entity = ProductEntity(barcode: '123456789012', name: 'Test');

        expect(entity.price, 0.0);
        expect(entity.stock, 0);
        expect(entity.isQuickTile, false);
        expect(entity.tileColorHex, isNull);
        expect(entity.category, isNull);
      });
    });

    group('custom values', () {
      test('should store provided values', () {
        const entity = ProductEntity(
          barcode: '987654321098',
          name: 'Widget',
          price: 15.99,
          stock: 42,
          isQuickTile: true,
          tileColorHex: '#10B981',
          category: 'soft drinks',
        );

        expect(entity.barcode, '987654321098');
        expect(entity.name, 'Widget');
        expect(entity.price, 15.99);
        expect(entity.stock, 42);
        expect(entity.isQuickTile, true);
        expect(entity.tileColorHex, '#10B981');
        expect(entity.category, 'soft drinks');
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        const original = ProductEntity(
          barcode: '123',
          name: 'Original',
          price: 10.0,
          stock: 5,
          isQuickTile: false,
        );

        final modified = original.copyWith(
          name: 'Updated',
          stock: 10,
          category: 'mains',
        );

        expect(modified.barcode, '123');
        expect(modified.name, 'Updated');
        expect(modified.price, 10.0);
        expect(modified.stock, 10);
        expect(modified.category, 'mains');
      });

      test('should keep original fields when not specified', () {
        const original = ProductEntity(
          barcode: '123',
          name: 'Original',
          price: 10.0,
          stock: 5,
        );

        final modified = original.copyWith();

        expect(modified.barcode, '123');
        expect(modified.name, 'Original');
        expect(modified.price, 10.0);
        expect(modified.stock, 5);
        expect(modified.isQuickTile, false);
        expect(modified.category, isNull);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        const a = ProductEntity(
          barcode: '123',
          name: 'Test',
          price: 10.0,
          stock: 5,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );
        const b = ProductEntity(
          barcode: '123',
          name: 'Test',
          price: 10.0,
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

      test('should not be equal when category differs', () {
        const a = ProductEntity(barcode: '123', name: 'A', category: 'mains');
        const b = ProductEntity(barcode: '123', name: 'A', category: 'drinks');

        expect(a, isNot(equals(b)));
      });

      test('prepCategory defaults to food', () {
        const product = ProductEntity(barcode: '123', name: 'A');
        expect(product.prepCategory, PrepCategory.food);
      });

      test('copyWith updates prepCategory', () {
        const product = ProductEntity(barcode: '123', name: 'A');
        final updated = product.copyWith(prepCategory: PrepCategory.shisha);
        expect(updated.prepCategory, PrepCategory.shisha);
        expect(updated.barcode, product.barcode);
      });

      test('should not be equal when prepCategory differs', () {
        const a = ProductEntity(
          barcode: '123',
          name: 'A',
          prepCategory: PrepCategory.food,
        );
        const b = ProductEntity(
          barcode: '123',
          name: 'A',
          prepCategory: PrepCategory.beverage,
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
