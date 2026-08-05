import 'package:hive/hive.dart';

import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../domain/entities/product_category_entity.dart';
import '../../domain/repositories/i_category_repository.dart';

class CategoryRepository implements ICategoryRepository {
  final BusinessType _businessType;
  final Box<List> _box;

  CategoryRepository({
    required BusinessType businessType,
    required Box<List> box,
  })  : _businessType = businessType,
        _box = box;

  List<String> get _names {
    final stored = _box.get('categories');
    if (stored == null) return const [];
    return List<String>.from(stored);
  }

  @override
  Future<List<ProductCategory>> getCategories() async {
    if (_box.isEmpty) {
      final presets = BusinessTypeRegistry.defaultCategories[_businessType];
      if (presets != null && presets.isNotEmpty) {
        await _box.put('categories', presets);
        return presets.map(ProductCategory.new).toList();
      }
      await _box.put('categories', const <String>[]);
      return const [];
    }
    return _names.map(ProductCategory.new).toList();
  }

  @override
  Future<void> addCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final current = _names;
    final exists = current.any(
      (n) => n.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) return;
    await _box.put('categories', [...current, normalized]);
  }

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) return;
    final current = _names;
    if (!current.contains(oldName)) return;
    await _box.put(
      'categories',
      current.map((n) => n == oldName ? normalized : n).toList(),
    );
  }

  @override
  Future<void> deleteCategory(String name) async {
    final current = _names;
    if (!current.contains(name)) return;
    await _box.put('categories', current.where((n) => n != name).toList());
  }
}