import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

class AppSessionRecordModel extends SessionRecordEntity {
  const AppSessionRecordModel({
    required super.id,
    required super.shiftId,
    required super.stationId,
    required super.stationName,
    required super.parentCategory,
    required super.tier,
    super.startTime,
    super.endTime,
    super.durationMinutes,
    super.wasFixedDuration,
    super.fixedDurationMinutes,
    super.hourlyRate,
    super.minimumGameCost,
    super.subtotalPiastres,
    super.discountPiastres,
    super.taxPiastres,
    required super.totalPiastres,
    super.taxPercent,
    super.discountPercent,
    super.username,
    super.paymentType,
    super.amountPaidPiastres,
    super.status,
  });

  factory AppSessionRecordModel.fromEntity(SessionRecordEntity entity) =>
      AppSessionRecordModel(
        id: entity.id,
        shiftId: entity.shiftId,
        stationId: entity.stationId,
        stationName: entity.stationName,
        parentCategory: entity.parentCategory,
        tier: entity.tier,
        startTime: entity.startTime,
        endTime: entity.endTime,
        durationMinutes: entity.durationMinutes,
        wasFixedDuration: entity.wasFixedDuration,
        fixedDurationMinutes: entity.fixedDurationMinutes,
        hourlyRate: entity.hourlyRate,
        minimumGameCost: entity.minimumGameCost,
        subtotalPiastres: entity.subtotalPiastres,
        discountPiastres: entity.discountPiastres,
        taxPiastres: entity.taxPiastres,
        totalPiastres: entity.totalPiastres,
        taxPercent: entity.taxPercent,
        discountPercent: entity.discountPercent,
        username: entity.username,
        paymentType: entity.paymentType,
        amountPaidPiastres: entity.amountPaidPiastres,
        status: entity.status,
      );

  SessionRecordEntity toEntity() => SessionRecordEntity(
    id: id,
    shiftId: shiftId,
    stationId: stationId,
    stationName: stationName,
    parentCategory: parentCategory,
    tier: tier,
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    wasFixedDuration: wasFixedDuration,
    fixedDurationMinutes: fixedDurationMinutes,
    hourlyRate: hourlyRate,
    minimumGameCost: minimumGameCost,
    subtotalPiastres: subtotalPiastres,
    discountPiastres: discountPiastres,
    taxPiastres: taxPiastres,
    totalPiastres: totalPiastres,
    taxPercent: taxPercent,
    discountPercent: discountPercent,
    username: username,
    paymentType: paymentType,
    amountPaidPiastres: amountPaidPiastres,
    status: status,
  );
}

class AppSessionRecordModelAdapter extends TypeAdapter<AppSessionRecordModel> {
  @override
  final int typeId = 8;

  @override
  AppSessionRecordModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppSessionRecordModel(
      id: fields[0] as String? ?? '',
      shiftId: fields[1] as String? ?? '',
      stationId: fields[2] as String? ?? '',
      stationName: fields[3] as String? ?? '',
      parentCategory: fields[4] as String? ?? '',
      tier: SessionTier.values[fields[5] as int? ?? 0],
      startTime: fields[6] as DateTime?,
      endTime: fields[7] as DateTime?,
      durationMinutes: fields[8] as int? ?? 0,
      wasFixedDuration: fields[9] as bool? ?? false,
      fixedDurationMinutes: fields[10] as int?,
      hourlyRate: (fields[11] as num?)?.toDouble() ?? 0.0,
      minimumGameCost: fields[12] as int? ?? 0,
      subtotalPiastres: fields[13] as int? ?? 0,
      discountPiastres: fields[14] as int? ?? 0,
      taxPiastres: fields[15] as int? ?? 0,
      totalPiastres: fields[16] as int? ?? 0,
      taxPercent: fields[17] as int? ?? 0,
      discountPercent: fields[18] as int? ?? 0,
      username: fields[19] as String? ?? '',
      paymentType: fields[20] as String? ?? 'cash',
      amountPaidPiastres: fields[21] as int?,
      status: SessionRecordStatus.values[fields[22] as int? ?? 0],
    );
  }

  @override
  void write(BinaryWriter writer, AppSessionRecordModel obj) {
    writer.writeByte(23);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.shiftId);
    writer.writeByte(2);
    writer.write(obj.stationId);
    writer.writeByte(3);
    writer.write(obj.stationName);
    writer.writeByte(4);
    writer.write(obj.parentCategory);
    writer.writeByte(5);
    writer.write(obj.tier.index);
    writer.writeByte(6);
    writer.write(obj.startTime);
    writer.writeByte(7);
    writer.write(obj.endTime);
    writer.writeByte(8);
    writer.write(obj.durationMinutes);
    writer.writeByte(9);
    writer.write(obj.wasFixedDuration);
    writer.writeByte(10);
    writer.write(obj.fixedDurationMinutes);
    writer.writeByte(11);
    writer.write(obj.hourlyRate);
    writer.writeByte(12);
    writer.write(obj.minimumGameCost);
    writer.writeByte(13);
    writer.write(obj.subtotalPiastres);
    writer.writeByte(14);
    writer.write(obj.discountPiastres);
    writer.writeByte(15);
    writer.write(obj.taxPiastres);
    writer.writeByte(16);
    writer.write(obj.totalPiastres);
    writer.writeByte(17);
    writer.write(obj.taxPercent);
    writer.writeByte(18);
    writer.write(obj.discountPercent);
    writer.writeByte(19);
    writer.write(obj.username);
    writer.writeByte(20);
    writer.write(obj.paymentType);
    writer.writeByte(21);
    writer.write(obj.amountPaidPiastres);
    writer.writeByte(22);
    writer.write(obj.status.index);
  }
}
