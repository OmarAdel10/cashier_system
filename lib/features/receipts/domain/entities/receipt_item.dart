class ReceiptItem {
  final String name;
  final String barcode;
  final int quantity;
  final int unitPricePiastres;

  const ReceiptItem({
    required this.name,
    required this.barcode,
    required this.quantity,
    required this.unitPricePiastres,
  });

  int get totalPiastres => quantity * unitPricePiastres;

  ReceiptItem copyWith({String? name, String? barcode, int? quantity, int? unitPricePiastres}) {
    return ReceiptItem(
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPricePiastres: unitPricePiastres ?? this.unitPricePiastres,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          barcode == other.barcode &&
          quantity == other.quantity &&
          unitPricePiastres == other.unitPricePiastres;

  @override
  int get hashCode => Object.hash(name, barcode, quantity, unitPricePiastres);

  @override
  String toString() => 'ReceiptItem(name: $name, barcode: $barcode, quantity: $quantity, unitPricePiastres: $unitPricePiastres)';
}
