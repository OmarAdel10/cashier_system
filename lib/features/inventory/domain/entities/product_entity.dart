class ProductEntity {
  final String barcode;
  final String name;
  final double price;
  final double purchasePrice;
  final int stock;
  final bool isQuickTile;
  final String? tileColorHex;
  final String notes;

  const ProductEntity({
    required this.barcode,
    required this.name,
    this.price = 0.0,
    this.purchasePrice = 0.0,
    this.stock = 0,
    this.isQuickTile = false,
    this.tileColorHex,
    this.notes = '',
  });

  ProductEntity copyWith({
    String? barcode,
    String? name,
    double? price,
    double? purchasePrice,
    int? stock,
    bool? isQuickTile,
    String? tileColorHex,
    String? notes,
  }) {
    return ProductEntity(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      stock: stock ?? this.stock,
      isQuickTile: isQuickTile ?? this.isQuickTile,
      tileColorHex: tileColorHex ?? this.tileColorHex,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductEntity &&
          runtimeType == other.runtimeType &&
          barcode == other.barcode &&
          name == other.name &&
          price == other.price &&
          purchasePrice == other.purchasePrice &&
          stock == other.stock &&
          isQuickTile == other.isQuickTile &&
          tileColorHex == other.tileColorHex &&
          notes == other.notes;

  @override
  int get hashCode =>
      barcode.hashCode ^
      name.hashCode ^
      price.hashCode ^
      purchasePrice.hashCode ^
      stock.hashCode ^
      isQuickTile.hashCode ^
      tileColorHex.hashCode ^
      notes.hashCode;
}
