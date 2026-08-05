sealed class CategoryEvent {
  const CategoryEvent();
}

final class LoadCategories extends CategoryEvent {
  const LoadCategories();
}

final class AddCategory extends CategoryEvent {
  final String name;
  const AddCategory(this.name);
}

final class RenameCategory extends CategoryEvent {
  final String oldName;
  final String newName;
  const RenameCategory({required this.oldName, required this.newName});
}

final class DeleteCategory extends CategoryEvent {
  final String name;
  const DeleteCategory(this.name);
}