import 'package:cashier_system/features/inventory/domain/entities/product_category_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_category_repository.dart';

class FakeCategoryRepository implements ICategoryRepository {
  final List<String> names;

  bool failOnGet = false;

  FakeCategoryRepository([List<String>? initial]) : names = [...?initial];

  @override
  Future<List<ProductCategory>> getCategories() async {
    if (failOnGet) throw Exception('boom');
    return names.map(ProductCategory.new).toList();
  }

  @override
  Future<void> addCategory(String name) async {
    names.add(name);
  }

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    final index = names.indexOf(oldName);
    if (index >= 0) {
      names[index] = newName;
    }
  }

  @override
  Future<void> deleteCategory(String name) async {
    names.remove(name);
  }
}
