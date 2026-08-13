import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/features/inventory/data/repositories/category_repository.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_category_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_category_repository.dart';

void main() {
  late Box<List> box;
  late ICategoryRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
  });

  setUp(() async {
    box = await Hive.openBox<List>('test_categories');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_categories');
  });

  group('getCategories seeding', () {
    test('empty box + cafe returns presets and persists them', () async {
      repository = CategoryRepository(
        businessType: BusinessType.cafe,
        box: box,
      );

      final categories = await repository.getCategories();

      final names = categories.map((c) => c.name).toList();
      expect(names, isNotEmpty);
      expect(names, contains('hot drinks'));
      expect(box.get('categories'), isNotEmpty);
    });

    test('box already has data + cafe does not re-seed', () async {
      await box.put('categories', ['a']);
      repository = CategoryRepository(
        businessType: BusinessType.cafe,
        box: box,
      );

      final categories = await repository.getCategories();

      expect(categories.map((c) => c.name).toList(), ['a']);
    });

    test('retail with empty box stays empty (no presets)', () async {
      repository = CategoryRepository(
        businessType: BusinessType.retail,
        box: box,
      );

      final categories = await repository.getCategories();

      expect(categories, isEmpty);
    });
  });

  group('CRUD', () {
    setUp(() async {
      await box.put('categories', ['hot drinks', 'cold drinks']);
      repository = CategoryRepository(
        businessType: BusinessType.cafe,
        box: box,
      );
    });

    test('addCategory persists and dedupes case-insensitively', () async {
      await repository.addCategory('soda');
      await repository.addCategory('Hot Drinks');

      final names = (await repository.getCategories())
          .map((c) => c.name)
          .toList();

      expect(names, ['hot drinks', 'cold drinks', 'soda']);
    });

    test('renameCategory updates; missing old name is a no-op', () async {
      await repository.renameCategory('hot drinks', 'hot beverages');
      await repository.renameCategory('nope', 'x');

      final names = (await repository.getCategories())
          .map((c) => c.name)
          .toList();

      expect(names, ['hot beverages', 'cold drinks']);
    });

    test('deleteCategory removes; missing name is a no-op', () async {
      await repository.deleteCategory('cold drinks');
      await repository.deleteCategory('nope');

      final names = (await repository.getCategories())
          .map((c) => c.name)
          .toList();

      expect(names, ['hot drinks']);
    });
  });

  group('ProductCategory', () {
    test('equality and hashCode', () {
      expect(const ProductCategory('a'), const ProductCategory('a'));
      expect(const ProductCategory('a') == const ProductCategory('b'), isFalse);
      expect(const ProductCategory('a').hashCode, 'a'.hashCode);
    });
  });
}
