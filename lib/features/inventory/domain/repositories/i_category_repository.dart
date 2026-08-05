import '../entities/product_category_entity.dart';

abstract class ICategoryRepository {
  Future<List<ProductCategory>> getCategories();

  Future<void> addCategory(String name);

  Future<void> renameCategory(String oldName, String newName);

  Future<void> deleteCategory(String name);
}