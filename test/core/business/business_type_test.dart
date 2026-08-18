import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/business/business_type_registry.dart';

void main() {
  group('BusinessType behavior', () {
    test('grid types are cafe/restaurant/playstation/piastary', () {
      expect(BusinessType.cafe.isGridMode, isTrue);
      expect(BusinessType.restaurant.isGridMode, isTrue);
      expect(BusinessType.playstation.isGridMode, isTrue);
      expect(BusinessType.piastary.isGridMode, isTrue);
    });
    test('scanner types are retail/supermarket/clothes/pharmacy', () {
      expect(BusinessType.retail.isGridMode, isFalse);
      expect(BusinessType.supermarket.isGridMode, isFalse);
      expect(BusinessType.clothes.isGridMode, isFalse);
      expect(BusinessType.pharmacy.isGridMode, isFalse);
    });
    test('categories only for cafe/restaurant/piastary', () {
      expect(BusinessType.cafe.hasCategories, isTrue);
      expect(BusinessType.restaurant.hasCategories, isTrue);
      expect(BusinessType.piastary.hasCategories, isTrue);
      expect(BusinessType.retail.hasCategories, isFalse);
      expect(BusinessType.supermarket.hasCategories, isFalse);
      expect(BusinessType.clothes.hasCategories, isFalse);
      expect(BusinessType.pharmacy.hasCategories, isFalse);
      expect(BusinessType.playstation.hasCategories, isFalse);
    });
    test('time billing only for playstation', () {
      expect(BusinessType.playstation.isTimeBilling, isTrue);
      expect(BusinessType.cafe.isTimeBilling, isFalse);
      expect(BusinessType.retail.isTimeBilling, isFalse);
      expect(BusinessType.piastary.isTimeBilling, isFalse);
    });
    test('table billing only for cafe/restaurant', () {
      expect(BusinessType.cafe.isTableBilling, isTrue);
      expect(BusinessType.restaurant.isTableBilling, isTrue);
      expect(BusinessType.retail.isTableBilling, isFalse);
      expect(BusinessType.supermarket.isTableBilling, isFalse);
      expect(BusinessType.playstation.isTableBilling, isFalse);
      expect(BusinessType.clothes.isTableBilling, isFalse);
      expect(BusinessType.pharmacy.isTableBilling, isFalse);
      expect(BusinessType.piastary.isTableBilling, isFalse);
    });
    test('receipts are disabled only for playstation', () {
      expect(BusinessType.playstation.receiptsEnabled, isFalse);
      expect(BusinessType.cafe.receiptsEnabled, isTrue);
      expect(BusinessType.retail.receiptsEnabled, isTrue);
      expect(BusinessType.clothes.receiptsEnabled, isTrue);
      expect(BusinessType.pharmacy.receiptsEnabled, isTrue);
      expect(BusinessType.piastary.receiptsEnabled, isTrue);
    });
    test('barcodes enabled only for scanner modes', () {
      expect(BusinessType.retail.barcodesEnabled, isTrue);
      expect(BusinessType.supermarket.barcodesEnabled, isTrue);
      expect(BusinessType.clothes.barcodesEnabled, isTrue);
      expect(BusinessType.pharmacy.barcodesEnabled, isTrue);
      expect(BusinessType.cafe.barcodesEnabled, isFalse);
      expect(BusinessType.restaurant.barcodesEnabled, isFalse);
      expect(BusinessType.playstation.barcodesEnabled, isFalse);
      expect(BusinessType.piastary.barcodesEnabled, isFalse);
    });
    test('stock enabled only for scanner modes', () {
      expect(BusinessType.retail.stockEnabled, isTrue);
      expect(BusinessType.clothes.stockEnabled, isTrue);
      expect(BusinessType.pharmacy.stockEnabled, isTrue);
      expect(BusinessType.restaurant.stockEnabled, isFalse);
      expect(BusinessType.piastary.stockEnabled, isFalse);
    });
    test('favorites only for categorized types', () {
      expect(BusinessType.cafe.favoritesEnabled, isTrue);
      expect(BusinessType.restaurant.favoritesEnabled, isTrue);
      expect(BusinessType.piastary.favoritesEnabled, isTrue);
      expect(BusinessType.playstation.favoritesEnabled, isFalse);
      expect(BusinessType.retail.favoritesEnabled, isFalse);
      expect(BusinessType.clothes.favoritesEnabled, isFalse);
      expect(BusinessType.pharmacy.favoritesEnabled, isFalse);
    });
    test('fromId resolves known ids and falls back to retail', () {
      expect(BusinessType.fromId('restaurant'), BusinessType.restaurant);
      expect(BusinessType.fromId('supermarket'), BusinessType.supermarket);
      expect(BusinessType.fromId('clothes'), BusinessType.clothes);
      expect(BusinessType.fromId('pharmacy'), BusinessType.pharmacy);
      expect(BusinessType.fromId('piastary'), BusinessType.piastary);
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
    test('piastary presets cover bakery categories', () {
      final presets =
          BusinessTypeRegistry.defaultCategories[BusinessType.piastary]!;
      expect(presets, containsAll(['breads', 'pastries', 'cakes']));
    });
  });
}
