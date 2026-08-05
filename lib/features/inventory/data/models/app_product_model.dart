import 'package:hive/hive.dart';
import '../../domain/entities/product_entity.dart';

class AppProductModel extends ProductEntity {
  const AppProductModel({
    required super.barcode,
    required super.name,
    super.price,
    super.purchasePrice,
    super.stock,
    super.isQuickTile,
    super.tileColorHex,
    super.notes,
  });

  factory AppProductModel.fromJson(Map<String, dynamic> json) {
    return AppProductModel(
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] as int? ?? 0,
      isQuickTile: json['isQuickTile'] as bool? ?? false,
      tileColorHex: json['tileColorHex'] as String?,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'price': price,
    'purchasePrice': purchasePrice,
    'stock': stock,
    'isQuickTile': isQuickTile,
    'tileColorHex': tileColorHex,
    'notes': notes,
  };

  ProductEntity toEntity() => ProductEntity(
    barcode: barcode,
    name: name,
    price: price,
    purchasePrice: purchasePrice,
    stock: stock,
    isQuickTile: isQuickTile,
    tileColorHex: tileColorHex,
    notes: notes,
  );
}

class AppProductModelAdapter extends TypeAdapter<AppProductModel> {
  @override
  final int typeId = 1;

  @override
  AppProductModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppProductModel(
      barcode: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      price: (fields[2] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (fields[7] as num?)?.toDouble() ?? 0.0,
      stock: fields[3] as int? ?? 0,
      isQuickTile: fields[4] as bool? ?? false,
      tileColorHex: fields[5] as String?,
      notes: fields[6] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, AppProductModel obj) {
    writer.writeByte(8);
    writer.writeByte(0);
    writer.write(obj.barcode);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.price);
    writer.writeByte(3);
    writer.write(obj.stock);
    writer.writeByte(4);
    writer.write(obj.isQuickTile);
    writer.writeByte(5);
    writer.write(obj.tileColorHex);
    writer.writeByte(6);
    writer.write(obj.notes);
    writer.writeByte(7);
    writer.write(obj.purchasePrice);
  }
}
