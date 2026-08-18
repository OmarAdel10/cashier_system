enum BusinessType {
  retail,
  supermarket,
  cafe,
  restaurant,
  playstation;

  bool get isGridMode {
    return switch (this) {
      BusinessType.retail || BusinessType.supermarket => false,
      BusinessType.cafe ||
      BusinessType.restaurant ||
      BusinessType.playstation => true,
    };
  }

  bool get hasCategories =>
      this == BusinessType.cafe || this == BusinessType.restaurant;

  bool get isTimeBilling => this == BusinessType.playstation;

  bool get isTableBilling {
    return switch (this) {
      BusinessType.cafe || BusinessType.restaurant => true,
      BusinessType.retail ||
      BusinessType.supermarket ||
      BusinessType.playstation => false,
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
