import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/inventory/data/models/app_product_model.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('AppProductModel', () {
    group('fromJson', () {
      test('should return a valid model with all fields', () {
        final json = {
          'barcode': '123456789012',
          'name': 'Test Product',
          'price': 150.0,
          'purchasePrice': 90.0,
          'stock': 10,
          'isQuickTile': true,
          'tileColorHex': '#10B981',
          'category': 'hot drinks',
        };

        final model = AppProductModel.fromJson(json);

        expect(model.barcode, '123456789012');
        expect(model.name, 'Test Product');
        expect(model.price, 150.0);
        expect(model.purchasePrice, 90.0);
        expect(model.stock, 10);
        expect(model.isQuickTile, true);
        expect(model.tileColorHex, '#10B981');
        expect(model.category, 'hot drinks');
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final model = AppProductModel.fromJson(json);

        expect(model.barcode, '');
        expect(model.name, '');
        expect(model.price, 0.0);
        expect(model.purchasePrice, 0.0);
        expect(model.stock, 0);
        expect(model.isQuickTile, false);
        expect(model.tileColorHex, isNull);
        expect(model.category, isNull);
      });
    });

    group('toJson', () {
      test('should return a valid JSON map', () {
        const model = AppProductModel(
          barcode: '123456789012',
          name: 'Test Product',
          price: 150.0,
          purchasePrice: 90.0,
          stock: 10,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );

        final json = model.toJson();

        expect(json['barcode'], '123456789012');
        expect(json['name'], 'Test Product');
        expect(json['price'], 150.0);
        expect(json['purchasePrice'], 90.0);
        expect(json['stock'], 10);
        expect(json['isQuickTile'], true);
        expect(json['tileColorHex'], '#10B981');
      });
    });

    group('round-trip', () {
      test('should serialize and deserialize correctly', () {
        const original = AppProductModel(
          barcode: '987654321098',
          name: 'Widget',
          price: 25.50,
          purchasePrice: 12.00,
          stock: 100,
          isQuickTile: true,
          tileColorHex: '#F59E0B',
          category: 'desserts',
        );

        final json = original.toJson();
        final decoded = AppProductModel.fromJson(json);

        expect(decoded.barcode, original.barcode);
        expect(decoded.name, original.name);
        expect(decoded.price, original.price);
        expect(decoded.purchasePrice, original.purchasePrice);
        expect(decoded.stock, original.stock);
        expect(decoded.isQuickTile, original.isQuickTile);
        expect(decoded.tileColorHex, original.tileColorHex);
        expect(decoded.category, 'desserts');
        expect(json['category'], 'desserts');
      });
    });

    group('identity', () {
      test('should be a ProductEntity', () {
        const model = AppProductModel(barcode: '123', name: 'Test');
        expect(model, isA<ProductEntity>());
      });
    });

    group('toEntity', () {
      test('should convert to ProductEntity preserving all fields', () {
        const model = AppProductModel(
          barcode: '123',
          name: 'Test',
          price: 10.0,
          purchasePrice: 7.5,
          stock: 5,
          isQuickTile: true,
          tileColorHex: '#10B981',
        );

        final entity = model.toEntity();

        expect(entity, isA<ProductEntity>());
        expect(entity.barcode, '123');
        expect(entity.name, 'Test');
        expect(entity.price, 10.0);
        expect(entity.purchasePrice, 7.5);
        expect(entity.stock, 5);
        expect(entity.isQuickTile, true);
        expect(entity.tileColorHex, '#10B981');
        expect(entity.category, isNull);
      });
    });
  });

  group('AppProductModelAdapter', () {
    late Box<AppProductModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppProductModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppProductModel>('test_products');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_products');
    });

    test('should persist and retrieve model via Hive', () async {
      const model = AppProductModel(
        barcode: '123456789012',
        name: 'Hive Test',
        price: 99.99,
        purchasePrice: 55.55,
        stock: 7,
        isQuickTile: true,
        tileColorHex: '#10B981',
      );

      await box.put('product_1', model);
      final retrieved = box.get('product_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.barcode, '123456789012');
      expect(retrieved.name, 'Hive Test');
      expect(retrieved.price, 99.99);
      expect(retrieved.purchasePrice, 55.55);
      expect(retrieved.stock, 7);
      expect(retrieved.isQuickTile, true);
      expect(retrieved.tileColorHex, '#10B981');
    });

    test('should have typeId 1', () {
      expect(AppProductModelAdapter().typeId, 1);
    });

    test('should persist category via Hive', () async {
      const model = AppProductModel(
        barcode: 'cat1',
        name: 'Categorized',
        price: 5.0,
        category: 'cold drinks',
      );

      await box.put('product_cat', model);
      final retrieved = box.get('product_cat');

      expect(retrieved, isNotNull);
      expect(retrieved!.category, 'cold drinks');
    });
  });
}
