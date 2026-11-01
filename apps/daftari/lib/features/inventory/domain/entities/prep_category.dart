enum PrepCategory {
  food('food'),
  beverage('beverage'),
  shisha('shisha'),
  general('general'),
  dessert('dessert'),
  special('special');

  const PrepCategory(this.id);

  final String id;

  static const List<PrepCategory> all = PrepCategory.values;

  static PrepCategory fromId(String id) {
    return PrepCategory.values.firstWhere(
      (type) => type.id == id,
      orElse: () => PrepCategory.food,
    );
  }

  static List<PrepCategory> fromIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return PrepCategory.values;
    final known = ids.map(fromId).toSet();
    return PrepCategory.values.where(known.contains).toList();
  }
}
