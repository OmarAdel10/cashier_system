import 'package:hive/hive.dart';
import '../../domain/entities/product_entity.dart';

class AppProductModel extends ProductEntity {
  const AppProductModel({
    required super.barcode,
    required super.name,
    super.price,
    super.stock,
    super.isQuickTile,
    super.tileColorHex,
    super.notes,
    super.category,
    super.prepCategory,
  });

  factory AppProductModel.fromJson(Map<String, dynamic> json) {
    return AppProductModel(
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] as int? ?? 0,
      isQuickTile: json['isQuickTile'] as bool? ?? false,
      tileColorHex: json['tileColorHex'] as String?,
      notes: json['notes'] as String? ?? '',
      category: json['category'] as String?,
      prepCategory: _parsePrepCategory(json['prepCategory'] as String?),
    );
  }

  static PrepCategory _parsePrepCategory(String? raw) {
    if (raw == null || raw.isEmpty) return PrepCategory.food;
    for (final category in PrepCategory.values) {
      if (category.name == raw) return category;
    }
    return PrepCategory.food;
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'price': price,
    'stock': stock,
    'isQuickTile': isQuickTile,
    'tileColorHex': tileColorHex,
    'notes': notes,
    'category': category,
    'prepCategory': prepCategory.name,
  };

  ProductEntity toEntity() => ProductEntity(
    barcode: barcode,
    name: name,
    price: price,
    stock: stock,
    isQuickTile: isQuickTile,
    tileColorHex: tileColorHex,
    notes: notes,
    category: category,
    prepCategory: prepCategory,
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
      stock: fields[3] as int? ?? 0,
      isQuickTile: fields[4] as bool? ?? false,
      tileColorHex: fields[5] as String?,
      notes: fields[6] as String? ?? '',
      category: fields[8] as String?,
      prepCategory: fields[9] == null
          ? PrepCategory.food
          : PrepCategory.values[fields[9] as int],
    );
  }

  @override
  void write(BinaryWriter writer, AppProductModel obj) {
    writer.writeByte(9);
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
    writer.writeByte(8);
    writer.write(obj.category);
    writer.writeByte(9);
    writer.write(obj.prepCategory.index);
  }
}
