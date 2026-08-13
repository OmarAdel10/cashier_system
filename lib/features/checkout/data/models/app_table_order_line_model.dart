import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

class AppTableOrderLineModel extends TableOrderLine {
  const AppTableOrderLineModel({
    required super.name,
    super.barcode,
    super.quantity,
    super.unitPricePiastres,
    super.prepCategory,
  });

  factory AppTableOrderLineModel.fromEntity(TableOrderLine line) =>
      AppTableOrderLineModel(
        name: line.name,
        barcode: line.barcode,
        quantity: line.quantity,
        unitPricePiastres: line.unitPricePiastres,
        prepCategory: line.prepCategory,
      );

  TableOrderLine toEntity() => TableOrderLine(
    name: name,
    barcode: barcode,
    quantity: quantity,
    unitPricePiastres: unitPricePiastres,
    prepCategory: prepCategory,
  );
}

class AppTableOrderLineModelAdapter
    extends TypeAdapter<AppTableOrderLineModel> {
  @override
  final int typeId = 12;

  @override
  AppTableOrderLineModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppTableOrderLineModel(
      name: fields[0] as String? ?? '',
      barcode: fields[1] as String? ?? '',
      quantity: fields[2] as int? ?? 1,
      unitPricePiastres: fields[3] as int? ?? 0,
      prepCategory: fields[4] == null
          ? PrepCategory.food
          : _prepCategoryAt(fields[4] as int),
    );
  }

  PrepCategory _prepCategoryAt(int index) {
    if (index < 0 || index >= PrepCategory.values.length) {
      return PrepCategory.food;
    }
    return PrepCategory.values[index];
  }

  @override
  void write(BinaryWriter writer, AppTableOrderLineModel obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.barcode);
    writer.writeByte(2);
    writer.write(obj.quantity);
    writer.writeByte(3);
    writer.write(obj.unitPricePiastres);
    writer.writeByte(4);
    writer.write(obj.prepCategory.index);
  }
}
