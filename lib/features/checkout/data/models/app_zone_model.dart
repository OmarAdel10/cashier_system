import 'package:hive/hive.dart';
import '../../domain/entities/zone_entity.dart';

class AppZoneModel extends ZoneEntity {
  const AppZoneModel({required super.id, required super.name, super.kind});

  factory AppZoneModel.fromEntity(ZoneEntity entity) =>
      AppZoneModel(id: entity.id, name: entity.name, kind: entity.kind);

  ZoneEntity toEntity() => ZoneEntity(id: id, name: name, kind: kind);
}

class AppZoneModelAdapter extends TypeAdapter<AppZoneModel> {
  @override
  final int typeId = 11;

  @override
  AppZoneModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppZoneModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      kind: fields[2] == null
          ? ZoneKind.dineIn
          : ZoneKind.values[fields[2] as int],
    );
  }

  @override
  void write(BinaryWriter writer, AppZoneModel obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.kind.index);
  }
}
