import 'package:hive/hive.dart';
import '../../domain/entities/expense_entity.dart';

class AppExpenseModel extends ExpenseEntity {
  const AppExpenseModel({
    required super.id,
    required super.shiftId,
    required super.username,
    required super.lines,
    required super.createdAt,
    super.name,
  });

  factory AppExpenseModel.fromJson(Map<String, dynamic> json) {
    return AppExpenseModel(
      id: json['id'] as String? ?? '',
      shiftId: json['shiftId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map(
                (e) => ExpenseLineEntity(
                  barcode: e['barcode'] as String? ?? '',
                  name: e['name'] as String? ?? '',
                  quantity: e['quantity'] as int? ?? 0,
                  costPiastres: e['costPiastres'] as int? ?? 0,
                ),
              )
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shiftId': shiftId,
    'username': username,
    'lines': lines
        .map(
          (e) => <String, dynamic>{
            'barcode': e.barcode,
            'name': e.name,
            'quantity': e.quantity,
            'costPiastres': e.costPiastres,
          },
        )
        .toList(),
    'createdAt': createdAt.toIso8601String(),
    'name': name,
  };

  ExpenseEntity toEntity() => ExpenseEntity(
    id: id,
    shiftId: shiftId,
    username: username,
    lines: lines,
    createdAt: createdAt,
    name: name,
  );
}

class AppExpenseModelAdapter extends TypeAdapter<AppExpenseModel> {
  @override
  final int typeId = 13;

  @override
  AppExpenseModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppExpenseModel(
      id: fields[0] as String? ?? '',
      shiftId: fields[1] as String? ?? '',
      username: fields[2] as String? ?? '',
      lines:
          (fields[3] as List<dynamic>?)
              ?.map((e) => e as Map)
              .map(
                (m) => ExpenseLineEntity(
                  barcode: m['barcode'] as String? ?? '',
                  name: m['name'] as String? ?? '',
                  quantity: m['quantity'] as int? ?? 0,
                  costPiastres: m['costPiastres'] as int? ?? 0,
                ),
              )
              .toList() ??
          const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int? ?? 0),
      name: fields[5] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, AppExpenseModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.shiftId)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(
        obj.lines
            .map(
              (e) => <String, dynamic>{
                'barcode': e.barcode,
                'name': e.name,
                'quantity': e.quantity,
                'costPiastres': e.costPiastres,
              },
            )
            .toList(),
      )
      ..writeByte(4)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.name);
  }
}
