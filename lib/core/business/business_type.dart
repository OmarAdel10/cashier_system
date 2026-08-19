enum BusinessType {
  retail,
  supermarket,
  cafe,
  restaurant,
  playstation,
  clothes,
  pharmacy,
  piastary;

  bool get isGridMode {
    return switch (this) {
      BusinessType.retail ||
      BusinessType.supermarket ||
      BusinessType.clothes ||
      BusinessType.pharmacy => false,
      BusinessType.cafe ||
      BusinessType.restaurant ||
      BusinessType.playstation ||
      BusinessType.piastary => true,
    };
  }

  bool get hasCategories =>
      this == BusinessType.cafe ||
      this == BusinessType.restaurant ||
      this == BusinessType.piastary;

  bool get isTimeBilling => this == BusinessType.playstation;

  bool get isTableBilling {
    return switch (this) {
      BusinessType.cafe || BusinessType.restaurant => true,
      BusinessType.retail ||
      BusinessType.supermarket ||
      BusinessType.playstation ||
      BusinessType.clothes ||
      BusinessType.pharmacy ||
      BusinessType.piastary => false,
    };
  }

  bool get receiptsEnabled => !isTimeBilling;

  bool get barcodesEnabled => !isGridMode;

  bool get stockEnabled => !isGridMode;

  bool get favoritesEnabled => hasCategories;

  static BusinessType fromId(String id) {
    for (final type in BusinessType.values) {
      if (type.name == id) return type;
    }
    return BusinessType.retail;
  }
}
