import 'package:hive/hive.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/receipt_status.dart';

class AppReceiptModel extends ReceiptEntity {
  const AppReceiptModel({
    required super.id,
    required super.shiftId,
    required super.orderNumber,
    required super.items,
    required super.subtotalPiastres,
    super.discountPiastres,
    super.taxPiastres,
    required super.totalPiastres,
    super.taxPercent,
    super.discountPercent,
    required super.createdAt,
    required super.username,
    super.stockUpdated,
    super.stockFailedBarcodes,
    super.status,
    super.modificationCount,
  });

  factory AppReceiptModel.fromJson(Map<String, dynamic> json) {
    return AppReceiptModel(
      id: json['id'] as String? ?? '',
      shiftId: json['shiftId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReceiptItem(
                    name: e['name'] as String? ?? '',
                    barcode: e['barcode'] as String? ?? '',
                    quantity: e['quantity'] as int? ?? 0,
                    unitPricePiastres: e['unitPricePiastres'] as int? ?? 0,
                  ))
              .toList() ??
          [],
      subtotalPiastres: json['subtotalPiastres'] as int? ?? 0,
      discountPiastres: json['discountPiastres'] as int? ?? 0,
      taxPiastres: json['taxPiastres'] as int? ?? 0,
      totalPiastres: json['totalPiastres'] as int? ?? 0,
      taxPercent: json['taxPercent'] as int? ?? 0,
      discountPercent: json['discountPercent'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      username: json['username'] as String? ?? '',
      stockUpdated: json['stockUpdated'] as bool? ?? false,
      stockFailedBarcodes: (json['stockFailedBarcodes'] as List<dynamic>?)?.cast<String>() ?? const [],
      status: ReceiptStatus.values[json['status'] as int? ?? 0],
      modificationCount: json['modificationCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shiftId': shiftId,
        'orderNumber': orderNumber,
        'items': items.map((e) => {
              'name': e.name,
              'barcode': e.barcode,
              'quantity': e.quantity,
              'unitPricePiastres': e.unitPricePiastres,
            }).toList(),
        'subtotalPiastres': subtotalPiastres,
        'discountPiastres': discountPiastres,
        'taxPiastres': taxPiastres,
        'totalPiastres': totalPiastres,
        'taxPercent': taxPercent,
        'discountPercent': discountPercent,
        'createdAt': createdAt.toIso8601String(),
        'username': username,
        'stockUpdated': stockUpdated,
        'stockFailedBarcodes': stockFailedBarcodes,
        'status': status.index,
        'modificationCount': modificationCount,
      };

  ReceiptEntity toEntity() => ReceiptEntity(
        id: id,
        shiftId: shiftId,
        orderNumber: orderNumber,
        items: items,
        subtotalPiastres: subtotalPiastres,
        discountPiastres: discountPiastres,
        taxPiastres: taxPiastres,
        totalPiastres: totalPiastres,
        taxPercent: taxPercent,
        discountPercent: discountPercent,
        createdAt: createdAt,
        username: username,
        stockUpdated: stockUpdated,
        stockFailedBarcodes: stockFailedBarcodes,
        status: status,
        modificationCount: modificationCount,
      );
}

class AppReceiptModelAdapter extends TypeAdapter<AppReceiptModel> {
  @override final int typeId = 4;

  @override
  AppReceiptModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppReceiptModel(
      id: fields[0] as String? ?? '',
      shiftId: fields[1] as String? ?? '',
      orderNumber: fields[2] as String? ?? '',
      items: (fields[3] as List<dynamic>?)
              ?.map((e) => e as ReceiptItem)
              .toList() ??
          [],
      subtotalPiastres: fields[4] as int? ?? 0,
      discountPiastres: fields[5] as int? ?? 0,
      taxPiastres: fields[6] as int? ?? 0,
      totalPiastres: fields[7] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[8] as int? ?? 0),
      username: fields[9] as String? ?? '',
      stockUpdated: fields[10] as bool? ?? false,
      status: ReceiptStatus.values[fields[11] as int? ?? 0],
      modificationCount: (fields[12] as int?) ?? 0,
      stockFailedBarcodes: (fields[13] as List<dynamic>?)?.cast<String>() ?? const [],
      taxPercent: fields[14] as int? ?? 0,
      discountPercent: fields[15] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AppReceiptModel obj) {
    writer.writeByte(16);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.shiftId);
    writer.writeByte(2); writer.write(obj.orderNumber);
    writer.writeByte(3); writer.write(obj.items);
    writer.writeByte(4); writer.write(obj.subtotalPiastres);
    writer.writeByte(5); writer.write(obj.discountPiastres);
    writer.writeByte(6); writer.write(obj.taxPiastres);
    writer.writeByte(7); writer.write(obj.totalPiastres);
    writer.writeByte(8); writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.writeByte(9); writer.write(obj.username);
    writer.writeByte(10); writer.write(obj.stockUpdated);
    writer.writeByte(11); writer.write(obj.status.index);
    writer.writeByte(12); writer.write(obj.modificationCount);
    writer.writeByte(13); writer.write(obj.stockFailedBarcodes);
    writer.writeByte(14); writer.write(obj.taxPercent);
    writer.writeByte(15); writer.write(obj.discountPercent);
  }
}
