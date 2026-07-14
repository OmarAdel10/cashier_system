import 'package:hive/hive.dart';
import '../../domain/entities/refund_entity.dart';

class AppRefundModel extends RefundEntity {
  const AppRefundModel({
    required super.id,
    required super.originalReceiptId,
    required super.refundDate,
    required super.amountRestored,
    required super.type,
  });

  factory AppRefundModel.fromJson(Map<String, dynamic> json) {
    return AppRefundModel(
      id: json['id'] as String? ?? '',
      originalReceiptId: json['originalReceiptId'] as String? ?? '',
      refundDate: DateTime.tryParse(json['refundDate'] as String? ?? '') ?? DateTime.now(),
      amountRestored: json['amountRestored'] as int? ?? 0,
      type: RefundType.values[json['type'] as int? ?? 0],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalReceiptId': originalReceiptId,
        'refundDate': refundDate.toIso8601String(),
        'amountRestored': amountRestored,
        'type': type.index,
      };

  RefundEntity toEntity() => RefundEntity(
        id: id,
        originalReceiptId: originalReceiptId,
        refundDate: refundDate,
        amountRestored: amountRestored,
        type: type,
      );
}

class AppRefundModelAdapter extends TypeAdapter<AppRefundModel> {
  @override final int typeId = 5;

  @override
  AppRefundModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppRefundModel(
      id: fields[0] as String? ?? '',
      originalReceiptId: fields[1] as String? ?? '',
      refundDate: DateTime.fromMillisecondsSinceEpoch(fields[2] as int? ?? 0),
      amountRestored: fields[3] as int? ?? 0,
      type: RefundType.values[fields[4] as int? ?? 0],
    );
  }

  @override
  void write(BinaryWriter writer, AppRefundModel obj) {
    writer.writeByte(5);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.originalReceiptId);
    writer.writeByte(2); writer.write(obj.refundDate.millisecondsSinceEpoch);
    writer.writeByte(3); writer.write(obj.amountRestored);
    writer.writeByte(4); writer.write(obj.type.index);
  }
}
