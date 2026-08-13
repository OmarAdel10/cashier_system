import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

class TableOrderLine {
  final String name;
  final String barcode;
  final int quantity;
  final int unitPricePiastres;
  final PrepCategory prepCategory;

  const TableOrderLine({
    required this.name,
    this.barcode = '',
    this.quantity = 1,
    this.unitPricePiastres = 0,
    this.prepCategory = PrepCategory.food,
  });

  TableOrderLine copyWith({
    String? name,
    String? barcode,
    int? quantity,
    int? unitPricePiastres,
    PrepCategory? prepCategory,
  }) {
    return TableOrderLine(
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPricePiastres: unitPricePiastres ?? this.unitPricePiastres,
      prepCategory: prepCategory ?? this.prepCategory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableOrderLine &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          barcode == other.barcode &&
          quantity == other.quantity &&
          unitPricePiastres == other.unitPricePiastres &&
          prepCategory == other.prepCategory;

  @override
  int get hashCode =>
      name.hashCode ^
      barcode.hashCode ^
      quantity.hashCode ^
      unitPricePiastres.hashCode ^
      prepCategory.hashCode;
}
