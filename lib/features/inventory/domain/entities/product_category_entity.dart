class ProductCategory {
  const ProductCategory(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCategory && name == other.name;

  @override
  int get hashCode => name.hashCode;
}