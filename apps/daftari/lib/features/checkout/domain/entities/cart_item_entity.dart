class CartItemEntity {
  final String barcode;
  final String name;
  final int quantity;
  final int unitPricePiastres;

  const CartItemEntity({
    required this.barcode,
    required this.name,
    this.quantity = 1,
    required this.unitPricePiastres,
  });

  int get totalPiastres => quantity * unitPricePiastres;

  CartItemEntity copyWith({
    String? barcode,
    String? name,
    int? quantity,
    int? unitPricePiastres,
  }) {
    return CartItemEntity(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPricePiastres: unitPricePiastres ?? this.unitPricePiastres,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemEntity &&
          runtimeType == other.runtimeType &&
          barcode == other.barcode &&
          name == other.name &&
          quantity == other.quantity &&
          unitPricePiastres == other.unitPricePiastres;

  @override
  int get hashCode =>
      barcode.hashCode ^
      name.hashCode ^
      quantity.hashCode ^
      unitPricePiastres.hashCode;
}
