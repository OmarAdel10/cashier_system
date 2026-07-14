import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/inventory/data/models/app_product_model.dart';
import 'package:cashier_system/features/inventory/data/repositories/inventory_repository.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';

void main() {
  late Box<AppProductModel> box;
  late IInventoryRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppProductModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppProductModel>('test_inventory');
    repository = InventoryRepository(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_inventory');
  });

  ProductEntity unwrap(Either<Failure, ProductEntity> result) {
    return result.fold(
      (failure) => throw failure,
      (product) => product,
    );
  }

  group('getInventory', () {
    test('should return empty map when box is empty', () async {
      final result = await repository.getInventory();
      final inventory = result.fold(
        (failure) => throw failure,
        (map) => map,
      );

      expect(inventory, isEmpty);
    });

    test('should return all stored products', () async {
      const product1 = ProductEntity(barcode: '111', name: 'Item 1', price: 10.0, stock: 5);
      const product2 = ProductEntity(barcode: '222', name: 'Item 2', price: 20.0, stock: 3);
      await repository.saveProduct(product1);
      await repository.saveProduct(product2);

      final result = await repository.getInventory();
      final inventory = result.fold(
        (failure) => throw failure,
        (map) => map,
      );

      expect(inventory.length, 2);
      expect(inventory['111']?.name, 'Item 1');
      expect(inventory['222']?.name, 'Item 2');
    });
  });

  group('saveProduct', () {
    test('should persist product and retrieve it', () async {
      const entity = ProductEntity(
        barcode: '123456789012',
        name: 'Test Product',
        price: 15.99,
        stock: 42,
        isQuickTile: true,
        tileColorHex: '#10B981',
      );

      final saveResult = await repository.saveProduct(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123456789012'],
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test Product');
      expect(retrieved.price, 15.99);
      expect(retrieved.stock, 42);
      expect(retrieved.isQuickTile, true);
      expect(retrieved.tileColorHex, '#10B981');
    });

    test('should overwrite existing product with same barcode', () async {
      const first = ProductEntity(barcode: '123', name: 'First');
      const second = ProductEntity(barcode: '123', name: 'Second', price: 99.0);

      await repository.saveProduct(first);
      await repository.saveProduct(second);

      final result = await repository.getInventory();
      final inventory = result.fold(
        (failure) => throw failure,
        (map) => map,
      );

      expect(inventory.length, 1);
      expect(inventory['123']?.name, 'Second');
      expect(inventory['123']?.price, 99.0);
    });
  });

  group('deleteProduct', () {
    test('should remove product from inventory', () async {
      const entity = ProductEntity(barcode: '123', name: 'To Delete');
      await repository.saveProduct(entity);

      final deleteResult = await repository.deleteProduct('123');
      expect(deleteResult, isA<Right<Failure, void>>());

      final result = await repository.getInventory();
      final inventory = result.fold(
        (failure) => throw failure,
        (map) => map,
      );

      expect(inventory, isEmpty);
    });

    test('should succeed when product does not exist', () async {
      final result = await repository.deleteProduct('nonexistent');
      expect(result, isA<Right<Failure, void>>());
    });
  });

  group('getQuickTiles', () {
    test('should return empty list when no quick tiles', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', isQuickTile: false);
      await repository.saveProduct(product);

      final result = await repository.getQuickTiles();
      final tiles = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(tiles, isEmpty);
    });

    test('should return only quick tile products', () async {
      await repository.saveProduct(ProductEntity(barcode: '111', name: 'Tile', isQuickTile: true, tileColorHex: '#10B981'));
      await repository.saveProduct(ProductEntity(barcode: '222', name: 'Normal', isQuickTile: false));
      await repository.saveProduct(ProductEntity(barcode: '333', name: 'Tile 2', isQuickTile: true, tileColorHex: '#F59E0B'));

      final result = await repository.getQuickTiles();
      final tiles = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(tiles.length, 2);
      expect(tiles.any((p) => p.barcode == '111'), isTrue);
      expect(tiles.any((p) => p.barcode == '333'), isTrue);
    });
  });

  group('toggleQuickTile', () {
    test('should toggle isQuickTile on existing product', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', isQuickTile: false);
      await repository.saveProduct(product);

      await repository.toggleQuickTile('123');

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123'],
      );
      expect(retrieved!.isQuickTile, isTrue);
    });

    test('should return ItemNotFoundFailure for missing product', () async {
      final result = await repository.toggleQuickTile('nonexistent');
      result.fold(
        (failure) => expect(failure, isA<ItemNotFoundFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateTileColor', () {
    test('should update tileColorHex on existing product', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', tileColorHex: '#fff');
      await repository.saveProduct(product);

      await repository.updateTileColor('123', '#000');

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123'],
      );
      expect(retrieved!.tileColorHex, '#000');
    });

    test('should return ItemNotFoundFailure for missing product', () async {
      final result = await repository.updateTileColor('nonexistent', '#000');
      result.fold(
        (failure) => expect(failure, isA<ItemNotFoundFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateStock', () {
    test('should add stock with positive delta (restore)', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', stock: 5);
      await repository.saveProduct(product);

      await repository.updateStock('123', 3);

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123'],
      );
      expect(retrieved!.stock, 8);
    });

    test('should subtract stock with negative delta (decrement)', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', stock: 10);
      await repository.saveProduct(product);

      await repository.updateStock('123', -4);

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123'],
      );
      expect(retrieved!.stock, 6);
    });

    test('should allow stock to go negative', () async {
      const product = ProductEntity(barcode: '123', name: 'Test', stock: 2);
      await repository.saveProduct(product);

      await repository.updateStock('123', -5);

      final result = await repository.getInventory();
      final retrieved = result.fold(
        (failure) => throw failure,
        (map) => map['123'],
      );
      expect(retrieved!.stock, -3);
    });

    test('should return ItemNotFoundFailure for nonexistent barcode', () async {
      final result = await repository.updateStock('nonexistent', 1);
      result.fold(
        (failure) => expect(failure, isA<ItemNotFoundFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
