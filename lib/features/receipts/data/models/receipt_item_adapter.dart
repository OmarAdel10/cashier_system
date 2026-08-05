import 'package:hive/hive.dart';
import '../../domain/entities/receipt_item.dart';

class ReceiptItemAdapter extends TypeAdapter<ReceiptItem> {
  @override
  final int typeId = 6;

  @override
  ReceiptItem read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return ReceiptItem(
      name: fields[0] as String? ?? '',
      barcode: fields[1] as String? ?? '',
      quantity: fields[2] as int? ?? 0,
      unitPricePiastres: fields[3] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ReceiptItem obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.barcode);
    writer.writeByte(2);
    writer.write(obj.quantity);
    writer.writeByte(3);
    writer.write(obj.unitPricePiastres);
  }
}
