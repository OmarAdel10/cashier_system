import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';

class AppTableRoundModel extends TableRoundEntity {
  const AppTableRoundModel({
    required super.id,
    required super.tableId,
    required super.roundNumber,
    required super.lines,
    required super.firedAt,
    super.status,
  });

  factory AppTableRoundModel.fromEntity(TableRoundEntity round) =>
      AppTableRoundModel(
        id: round.id,
        tableId: round.tableId,
        roundNumber: round.roundNumber,
        lines: round.lines
            .map(AppTableOrderLineModel.fromEntity)
            .toList(growable: false),
        firedAt: round.firedAt,
        status: round.status,
      );

  TableRoundEntity toEntity() => TableRoundEntity(
    id: id,
    tableId: tableId,
    roundNumber: roundNumber,
    lines: lines
        .map((line) => (line as AppTableOrderLineModel).toEntity())
        .toList(growable: false),
    firedAt: firedAt,
    status: status,
  );
}

class AppTableRoundModelAdapter extends TypeAdapter<AppTableRoundModel> {
  @override
  final int typeId = 10;

  @override
  AppTableRoundModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppTableRoundModel(
      id: fields[0] as String? ?? '',
      tableId: fields[1] as String? ?? '',
      roundNumber: fields[2] as int? ?? 1,
      lines: (fields[3] as List? ?? const <AppTableOrderLineModel>[])
          .cast<AppTableOrderLineModel>(),
      firedAt: fields[4] as DateTime? ?? DateTime.now(),
      status: RoundStatus.values[fields[5] as int? ?? 0],
    );
  }

  @override
  void write(BinaryWriter writer, AppTableRoundModel obj) {
    writer.writeByte(6);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.tableId);
    writer.writeByte(2);
    writer.write(obj.roundNumber);
    writer.writeByte(3);
    writer.write(obj.lines);
    writer.writeByte(4);
    writer.write(obj.firedAt);
    writer.writeByte(5);
    writer.write(obj.status.index);
  }
}
