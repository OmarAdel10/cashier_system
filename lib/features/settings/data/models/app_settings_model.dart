import 'package:hive/hive.dart';
import '../../domain/entities/app_settings_entity.dart';

class AppSettingsModel extends AppSettingsEntity {
  const AppSettingsModel({
    super.languageCode,
    super.isDarkMode,
    super.storeName,
    super.receiptFootnote,
    super.customBindings,
    super.taxEnabled,
    super.taxPercent,
    super.autoPrintEnabled,
    super.orderCounter,
    super.lastOrderDate,
    super.exportDirectoryPath,
    super.saveReceiptAsImage,
    super.storeAddress,
    super.storePhoneNumber,
    super.logoSvgPath,
    super.receiptPrinterName,
    super.barcodePrinterName,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      languageCode: json['languageCode'] as String? ?? 'ar',
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      storeName: json['storeName'] as String? ?? '',
      receiptFootnote: json['receiptFootnote'] as String? ?? '',
      customBindings: _parseCustomBindings(
          json['customBindings'] as Map<String, dynamic>?),
      taxEnabled: json['taxEnabled'] as bool? ?? false,
      taxPercent: json['taxPercent'] as int? ?? 0,
      autoPrintEnabled: json['autoPrintEnabled'] as bool? ?? false,
      orderCounter: json['orderCounter'] as int? ?? 0,
      lastOrderDate: json['lastOrderDate'] as String? ?? '',
      exportDirectoryPath: json['exportDirectoryPath'] as String? ?? '',
      saveReceiptAsImage: json['saveReceiptAsImage'] as bool? ?? false,
      storeAddress: json['storeAddress'] as String? ?? '',
      storePhoneNumber: json['storePhoneNumber'] as String? ?? '',
      logoSvgPath: json['logoSvgPath'] as String?,
      receiptPrinterName: json['receiptPrinterName'] as String?,
      barcodePrinterName: json['barcodePrinterName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languageCode': languageCode,
      'isDarkMode': isDarkMode,
      'storeName': storeName,
      'receiptFootnote': receiptFootnote,
      'customBindings': customBindings,
      'taxEnabled': taxEnabled,
      'taxPercent': taxPercent,
      'autoPrintEnabled': autoPrintEnabled,
      'orderCounter': orderCounter,
      'lastOrderDate': lastOrderDate,
      'exportDirectoryPath': exportDirectoryPath,
      'saveReceiptAsImage': saveReceiptAsImage,
      'storeAddress': storeAddress,
      'storePhoneNumber': storePhoneNumber,
      'logoSvgPath': logoSvgPath,
      'receiptPrinterName': receiptPrinterName,
      'barcodePrinterName': barcodePrinterName,
    };
  }

  AppSettingsEntity toEntity() {
    return AppSettingsEntity(
      languageCode: languageCode,
      isDarkMode: isDarkMode,
      storeName: storeName,
      receiptFootnote: receiptFootnote,
      customBindings: customBindings,
      taxEnabled: taxEnabled,
      taxPercent: taxPercent,
      autoPrintEnabled: autoPrintEnabled,
      orderCounter: orderCounter,
      lastOrderDate: lastOrderDate,
      exportDirectoryPath: exportDirectoryPath,
      saveReceiptAsImage: saveReceiptAsImage,
      storeAddress: storeAddress,
      storePhoneNumber: storePhoneNumber,
      logoSvgPath: logoSvgPath,
      receiptPrinterName: receiptPrinterName,
      barcodePrinterName: barcodePrinterName,
    );
  }

  static Map<String, List<String>> _parseCustomBindings(
      Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    return raw.map((k, v) {
      if (v is String) {
        return MapEntry(k, [v]);
      }
      if (v is List) {
        return MapEntry(k, v.map((e) => e as String).toList());
      }
      return MapEntry(k, <String>[]);
    });
  }
}

class AppSettingsModelAdapter extends TypeAdapter<AppSettingsModel> {
  @override
  final int typeId = 0;

  @override
  AppSettingsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return AppSettingsModel(
      languageCode: fields[0] as String? ?? 'ar',
      isDarkMode: fields[1] as bool? ?? false,
      storeName: fields[2] as String? ?? '',
      receiptFootnote: fields[3] as String? ?? '',
      customBindings: (() {
        final f4 = fields[4];
        if (f4 == null) return const <String, List<String>>{};
        final map = f4 as Map;
        return map.map((k, v) {
          if (v is String) return MapEntry(k as String, [v]);
          if (v is List) return MapEntry(k as String, v.map((e) => e as String).toList());
          return MapEntry(k as String, <String>[]);
        });
      })(),
      taxEnabled: fields[5] as bool? ?? false,
      taxPercent: fields[6] as int? ?? 0,
      autoPrintEnabled: fields[7] as bool? ?? false,
      orderCounter: fields[8] as int? ?? 0,
      lastOrderDate: fields[9] as String? ?? '',
      exportDirectoryPath: fields[10] as String? ?? '',
      saveReceiptAsImage: fields[11] as bool? ?? false,
      storeAddress: fields[12] as String? ?? '',
      storePhoneNumber: fields[13] as String? ?? '',
      logoSvgPath: fields[14] as String?,
      receiptPrinterName: fields[15] as String?,
      barcodePrinterName: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer.writeByte(17);
    writer.writeByte(0);
    writer.write(obj.languageCode);
    writer.writeByte(1);
    writer.write(obj.isDarkMode);
    writer.writeByte(2);
    writer.write(obj.storeName);
    writer.writeByte(3);
    writer.write(obj.receiptFootnote);
    writer.writeByte(4);
    writer.write(obj.customBindings);
    writer.writeByte(5);
    writer.write(obj.taxEnabled);
    writer.writeByte(6);
    writer.write(obj.taxPercent);
    writer.writeByte(7);
    writer.write(obj.autoPrintEnabled);
    writer.writeByte(8);
    writer.write(obj.orderCounter);
    writer.writeByte(9);
    writer.write(obj.lastOrderDate);
    writer.writeByte(10);
    writer.write(obj.exportDirectoryPath);
    writer.writeByte(11);
    writer.write(obj.saveReceiptAsImage);
    writer.writeByte(12);
    writer.write(obj.storeAddress);
    writer.writeByte(13);
    writer.write(obj.storePhoneNumber);
    writer.writeByte(14);
    writer.write(obj.logoSvgPath);
    writer.writeByte(15);
    writer.write(obj.receiptPrinterName);
    writer.writeByte(16);
    writer.write(obj.barcodePrinterName);
  }
}
