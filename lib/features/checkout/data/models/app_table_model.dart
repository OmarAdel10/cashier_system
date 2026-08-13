import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';

class AppTableModel extends TableEntity {
  const AppTableModel({
    required super.id,
    required super.name,
    super.zoneId,
    super.capacity,
    super.isRoom,
    super.hourlyRatePiastres,
    super.status,
    super.tabOpenedAt,
    super.activeRoundNumber,
  });

  factory AppTableModel.fromEntity(TableEntity entity) => AppTableModel(
    id: entity.id,
    name: entity.name,
    zoneId: entity.zoneId,
    capacity: entity.capacity,
    isRoom: entity.isRoom,
    hourlyRatePiastres: entity.hourlyRatePiastres,
    status: entity.status,
    tabOpenedAt: entity.tabOpenedAt,
    activeRoundNumber: entity.activeRoundNumber,
  );

  TableEntity toEntity() => TableEntity(
    id: id,
    name: name,
    zoneId: zoneId,
    capacity: capacity,
    isRoom: isRoom,
    hourlyRatePiastres: hourlyRatePiastres,
    status: status,
    tabOpenedAt: tabOpenedAt,
    activeRoundNumber: activeRoundNumber,
  );
}

class AppTableModelAdapter extends TypeAdapter<AppTableModel> {
  @override
  final int typeId = 9;

  @override
  AppTableModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppTableModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      zoneId: fields[2] as String? ?? '',
      capacity: fields[3] as int? ?? 1,
      isRoom: fields[4] as bool? ?? false,
      hourlyRatePiastres: fields[5] as int? ?? 0,
      status: TableStatus.values[fields[6] as int? ?? 0],
      tabOpenedAt: fields[7] as DateTime?,
      activeRoundNumber: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AppTableModel obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.zoneId);
    writer.writeByte(3);
    writer.write(obj.capacity);
    writer.writeByte(4);
    writer.write(obj.isRoom);
    writer.writeByte(5);
    writer.write(obj.hourlyRatePiastres);
    writer.writeByte(6);
    writer.write(obj.status.index);
    writer.writeByte(7);
    writer.write(obj.tabOpenedAt);
    writer.writeByte(8);
    writer.write(obj.activeRoundNumber);
  }
}
