import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/business/business_type_registry.dart';

void main() {
  group('BusinessType behavior', () {
    test('grid types are cafe/restaurant/playstation', () {
      expect(BusinessType.cafe.isGridMode, isTrue);
      expect(BusinessType.restaurant.isGridMode, isTrue);
      expect(BusinessType.playstation.isGridMode, isTrue);
    });
    test('scanner types are retail/supermarket', () {
      expect(BusinessType.retail.isGridMode, isFalse);
      expect(BusinessType.supermarket.isGridMode, isFalse);
    });
    test('categories only for cafe/restaurant', () {
      expect(BusinessType.cafe.hasCategories, isTrue);
      expect(BusinessType.restaurant.hasCategories, isTrue);
      expect(BusinessType.retail.hasCategories, isFalse);
      expect(BusinessType.supermarket.hasCategories, isFalse);
      expect(BusinessType.playstation.hasCategories, isFalse);
    });
    test('time billing only for playstation', () {
      expect(BusinessType.playstation.isTimeBilling, isTrue);
      expect(BusinessType.cafe.isTimeBilling, isFalse);
      expect(BusinessType.retail.isTimeBilling, isFalse);
    });
    test('receipts are disabled only for playstation', () {
      expect(BusinessType.playstation.receiptsEnabled, isFalse);
      expect(BusinessType.cafe.receiptsEnabled, isTrue);
      expect(BusinessType.retail.receiptsEnabled, isTrue);
    });
    test('barcodes enabled only for scanner modes', () {
      expect(BusinessType.retail.barcodesEnabled, isTrue);
      expect(BusinessType.supermarket.barcodesEnabled, isTrue);
      expect(BusinessType.cafe.barcodesEnabled, isFalse);
      expect(BusinessType.playstation.barcodesEnabled, isFalse);
    });
    test('stock enabled only for scanner modes', () {
      expect(BusinessType.retail.stockEnabled, isTrue);
      expect(BusinessType.restaurant.stockEnabled, isFalse);
    });
    test('favorites only for categorized types', () {
      expect(BusinessType.cafe.favoritesEnabled, isTrue);
      expect(BusinessType.restaurant.favoritesEnabled, isTrue);
      expect(BusinessType.playstation.favoritesEnabled, isFalse);
      expect(BusinessType.retail.favoritesEnabled, isFalse);
    });
    test('fromId resolves known ids and falls back to retail', () {
      expect(BusinessType.fromId('restaurant'), BusinessType.restaurant);
      expect(BusinessType.fromId('supermarket'), BusinessType.supermarket);
      expect(BusinessType.fromId('unknown'), BusinessType.retail);
    });
  });

  group('BusinessTypeRegistry', () {
    test('every type has metadata with businessType label key', () {
      for (final type in BusinessType.values) {
        final meta = BusinessTypeRegistry.metadata[type];
        expect(meta, isNotNull);
        expect(meta!.labelKey, startsWith('businessType.'));
      }
    });
    test('only categorized types have non-empty presets', () {
      for (final type in BusinessType.values) {
        final presets =
            BusinessTypeRegistry.defaultCategories[type] ?? const [];
        if (type.hasCategories) {
          expect(presets, isNotEmpty);
        } else {
          expect(presets, isEmpty);
        }
      }
    });
  });
}
