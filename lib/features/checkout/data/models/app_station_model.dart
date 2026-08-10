import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';

class AppStationModel extends StationEntity {
  const AppStationModel({
    required super.id,
    required super.name,
    required super.parentCategory,
    required super.stationType,
    required super.normalHourlyRate,
    required super.multiHourlyRate,
    required super.minimumGameCostNormal,
    required super.minimumGameCostMulti,
    required super.iconAsset,
    super.status,
    super.sessionStartTime,
    super.isFixedDuration,
    super.fixedDurationMinutes,
    super.overtimeStartMinutes,
    super.sessionTier,
    super.addonLines,
  });

  factory AppStationModel.fromEntity(StationEntity entity) => AppStationModel(
    id: entity.id,
    name: entity.name,
    parentCategory: entity.parentCategory,
    stationType: entity.stationType,
    normalHourlyRate: entity.normalHourlyRate,
    multiHourlyRate: entity.multiHourlyRate,
    minimumGameCostNormal: entity.minimumGameCostNormal,
    minimumGameCostMulti: entity.minimumGameCostMulti,
    iconAsset: entity.iconAsset,
    status: entity.status,
    sessionStartTime: entity.sessionStartTime,
    isFixedDuration: entity.isFixedDuration,
    fixedDurationMinutes: entity.fixedDurationMinutes,
    overtimeStartMinutes: entity.overtimeStartMinutes,
    sessionTier: entity.sessionTier,
    addonLines: entity.addonLines
        .map((l) => AppTableOrderLineModel.fromEntity(l))
        .toList(),
  );

  StationEntity toEntity() => StationEntity(
    id: id,
    name: name,
    parentCategory: parentCategory,
    stationType: stationType,
    normalHourlyRate: normalHourlyRate,
    multiHourlyRate: multiHourlyRate,
    minimumGameCostNormal: minimumGameCostNormal,
    minimumGameCostMulti: minimumGameCostMulti,
    iconAsset: iconAsset,
    status: status,
    sessionStartTime: sessionStartTime,
    isFixedDuration: isFixedDuration,
    fixedDurationMinutes: fixedDurationMinutes,
    overtimeStartMinutes: overtimeStartMinutes,
    sessionTier: sessionTier,
    addonLines: addonLines
        .map((l) => (l as AppTableOrderLineModel).toEntity())
        .toList(),
  );
}

class AppStationModelAdapter extends TypeAdapter<AppStationModel> {
  @override
  final int typeId = 7;

  @override
  AppStationModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppStationModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      parentCategory: fields[2] as String? ?? '',
      stationType: StationType.values[fields[3] as int? ?? 0],
      normalHourlyRate: (fields[4] as num?)?.toDouble() ?? 0.0,
      multiHourlyRate: (fields[5] as num?)?.toDouble() ?? 0.0,
      minimumGameCostNormal: fields[6] as int? ?? 0,
      minimumGameCostMulti: fields[7] as int? ?? 0,
      iconAsset: fields[8] as String? ?? '',
      status: StationStatus.values[fields[9] as int? ?? 0],
      sessionStartTime: fields[10] as DateTime?,
      isFixedDuration: fields[11] as bool? ?? false,
      fixedDurationMinutes: fields[12] as int?,
      overtimeStartMinutes: fields[13] as int?,
      sessionTier: fields[14] == null
          ? null
          : PricingTier.values[fields[14] as int],
    );
  }

  @override
  void write(BinaryWriter writer, AppStationModel obj) {
    writer.writeByte(15);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.parentCategory);
    writer.writeByte(3);
    writer.write(obj.stationType.index);
    writer.writeByte(4);
    writer.write(obj.normalHourlyRate);
    writer.writeByte(5);
    writer.write(obj.multiHourlyRate);
    writer.writeByte(6);
    writer.write(obj.minimumGameCostNormal);
    writer.writeByte(7);
    writer.write(obj.minimumGameCostMulti);
    writer.writeByte(8);
    writer.write(obj.iconAsset);
    writer.writeByte(9);
    writer.write(obj.status.index);
    writer.writeByte(10);
    writer.write(obj.sessionStartTime);
    writer.writeByte(11);
    writer.write(obj.isFixedDuration);
    writer.writeByte(12);
    writer.write(obj.fixedDurationMinutes);
    writer.writeByte(13);
    writer.write(obj.overtimeStartMinutes);
    writer.writeByte(14);
    writer.write(obj.sessionTier?.index);
  }
}
