import 'package:hive/hive.dart';
import '../../domain/entities/shift_entity.dart';

class AppShiftModel extends ShiftEntity {
  const AppShiftModel({
    required super.id,
    required super.username,
    required super.startedAt,
    super.endedAt,
    super.openingFloat,
  });

  factory AppShiftModel.fromJson(Map<String, dynamic> json) {
    return AppShiftModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      openingFloat: json['openingFloat'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'openingFloat': openingFloat,
  };

  ShiftEntity toEntity() => ShiftEntity(
    id: id,
    username: username,
    startedAt: startedAt,
    endedAt: endedAt,
    openingFloat: openingFloat,
  );
}

class AppShiftModelAdapter extends TypeAdapter<AppShiftModel> {
  @override
  final int typeId = 3;

  @override
  AppShiftModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppShiftModel(
      id: fields[0] as String? ?? '',
      username: fields[1] as String? ?? '',
      startedAt: fields[2] as DateTime? ?? DateTime.now(),
      endedAt: fields[3] as DateTime?,
      openingFloat: fields[4] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AppShiftModel obj) {
    writer.writeByte(5);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.username);
    writer.writeByte(2); writer.write(obj.startedAt);
    writer.writeByte(3); writer.write(obj.endedAt);
    writer.writeByte(4); writer.write(obj.openingFloat);
  }
}
