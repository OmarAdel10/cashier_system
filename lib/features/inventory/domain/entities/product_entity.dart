class ProductEntity {
  final String barcode;
  final String name;
  final double price;
  final int stock;
  final bool isQuickTile;
  final String? tileColorHex;

  const ProductEntity({
    required this.barcode,
    required this.name,
    this.price = 0.0,
    this.stock = 0,
    this.isQuickTile = false,
    this.tileColorHex,
  });

  ProductEntity copyWith({String? barcode, String? name, double? price, int? stock, bool? isQuickTile, String? tileColorHex}) {
    return ProductEntity(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isQuickTile: isQuickTile ?? this.isQuickTile,
      tileColorHex: tileColorHex ?? this.tileColorHex,
    );
  }

  @override bool operator ==(Object other) =>
      identical(this, other) || other is ProductEntity && runtimeType == other.runtimeType &&
      barcode == other.barcode && name == other.name && price == other.price &&
      stock == other.stock && isQuickTile == other.isQuickTile && tileColorHex == other.tileColorHex;

  @override int get hashCode => barcode.hashCode ^ name.hashCode ^ price.hashCode ^ stock.hashCode ^ isQuickTile.hashCode ^ tileColorHex.hashCode;
}
