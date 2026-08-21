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
    super.saveReceiptAsPdf,
    super.storeAddress,
    super.storePhoneNumber,
    super.logoSvgData,
    super.receiptPrinterName,
    super.barcodePrinterName,
    super.barcodeActionPreference,
    super.shownPaymentTypeIds,
    super.businessType,
    super.minimumGameCost,
    super.favoritesStripEnabled,
    super.roomsEnabled,
    super.serviceChargeEnabled,
    super.serviceChargePercent,
    super.minChargeEnabled,
    super.minChargePerTablePiastres,
    super.kitchenTicketsEnabled,
    super.kitchenPrinterName,
    super.barTicketsEnabled,
    super.barPrinterName,
    super.shishaTicketsEnabled,
    super.shishaPrinterName,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      languageCode: json['languageCode'] as String? ?? 'ar',
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      storeName: json['storeName'] as String? ?? '',
      receiptFootnote: json['receiptFootnote'] as String? ?? '',
      customBindings: _parseCustomBindings(
        json['customBindings'] as Map<String, dynamic>?,
      ),
      taxEnabled: json['taxEnabled'] as bool? ?? false,
      taxPercent: json['taxPercent'] as int? ?? 0,
      autoPrintEnabled: json['autoPrintEnabled'] as bool? ?? false,
      orderCounter: json['orderCounter'] as int? ?? 0,
      lastOrderDate: json['lastOrderDate'] as String? ?? '',
      exportDirectoryPath: json['exportDirectoryPath'] as String? ?? '',
      saveReceiptAsImage: json['saveReceiptAsImage'] as bool? ?? false,
      saveReceiptAsPdf: json['saveReceiptAsPdf'] as bool? ?? false,
      storeAddress: json['storeAddress'] as String? ?? '',
      storePhoneNumber: json['storePhoneNumber'] as String? ?? '',
      logoSvgData: json['logoSvgData'] as String?,
      receiptPrinterName: json['receiptPrinterName'] as String?,
      barcodePrinterName: json['barcodePrinterName'] as String?,
      barcodeActionPreference:
          json['barcodeActionPreference'] as String? ?? 'printDirect',
      shownPaymentTypeIds:
          (json['shownPaymentTypeIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
      businessType: json['businessType'] as String? ?? 'retail',
      minimumGameCost: json['minimumGameCost'] as int? ?? 500,
      favoritesStripEnabled: json['favoritesStripEnabled'] as bool? ?? false,
      roomsEnabled: json['roomsEnabled'] as bool? ?? false,
      serviceChargeEnabled: json['serviceChargeEnabled'] as bool? ?? false,
      serviceChargePercent: json['serviceChargePercent'] as int? ?? 12,
      minChargeEnabled: json['minChargeEnabled'] as bool? ?? false,
      minChargePerTablePiastres: json['minChargePerTablePiastres'] as int? ?? 0,
      kitchenTicketsEnabled: json['kitchenTicketsEnabled'] as bool? ?? true,
      kitchenPrinterName: json['kitchenPrinterName'] as String?,
      barTicketsEnabled: json['barTicketsEnabled'] as bool? ?? true,
      barPrinterName: json['barPrinterName'] as String?,
      shishaTicketsEnabled: json['shishaTicketsEnabled'] as bool? ?? true,
      shishaPrinterName: json['shishaPrinterName'] as String?,
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
      'saveReceiptAsPdf': saveReceiptAsPdf,
      'storeAddress': storeAddress,
      'storePhoneNumber': storePhoneNumber,
      'logoSvgData': logoSvgData,
      'receiptPrinterName': receiptPrinterName,
      'barcodePrinterName': barcodePrinterName,
      'barcodeActionPreference': barcodeActionPreference,
      'shownPaymentTypeIds': shownPaymentTypeIds,
      'businessType': businessType,
      'minimumGameCost': minimumGameCost,
      'favoritesStripEnabled': favoritesStripEnabled,
      'roomsEnabled': roomsEnabled,
      'serviceChargeEnabled': serviceChargeEnabled,
      'serviceChargePercent': serviceChargePercent,
      'minChargeEnabled': minChargeEnabled,
      'minChargePerTablePiastres': minChargePerTablePiastres,
      'kitchenTicketsEnabled': kitchenTicketsEnabled,
      'kitchenPrinterName': kitchenPrinterName,
      'barTicketsEnabled': barTicketsEnabled,
      'barPrinterName': barPrinterName,
      'shishaTicketsEnabled': shishaTicketsEnabled,
      'shishaPrinterName': shishaPrinterName,
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
      saveReceiptAsPdf: saveReceiptAsPdf,
      storeAddress: storeAddress,
      storePhoneNumber: storePhoneNumber,
      logoSvgData: logoSvgData,
      receiptPrinterName: receiptPrinterName,
      barcodePrinterName: barcodePrinterName,
      barcodeActionPreference: barcodeActionPreference,
      shownPaymentTypeIds: shownPaymentTypeIds,
      businessType: businessType,
      minimumGameCost: minimumGameCost,
      favoritesStripEnabled: favoritesStripEnabled,
      roomsEnabled: roomsEnabled,
      serviceChargeEnabled: serviceChargeEnabled,
      serviceChargePercent: serviceChargePercent,
      minChargeEnabled: minChargeEnabled,
      minChargePerTablePiastres: minChargePerTablePiastres,
      kitchenTicketsEnabled: kitchenTicketsEnabled,
      kitchenPrinterName: kitchenPrinterName,
      barTicketsEnabled: barTicketsEnabled,
      barPrinterName: barPrinterName,
      shishaTicketsEnabled: shishaTicketsEnabled,
      shishaPrinterName: shishaPrinterName,
    );
  }

  static Map<String, List<String>> _parseCustomBindings(
    Map<String, dynamic>? raw,
  ) {
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

  static bool overreadDetected = false;

  @override
  AppSettingsModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numFields; i++) {
      try {
        final key = reader.readByte();
        final value = reader.read();
        fields[key] = value;
      } catch (_) {
        overreadDetected = true;
        break;
      }
    }
    return AppSettingsModel(
      languageCode: fields[0] as String? ?? 'ar',
      isDarkMode: fields[1] as bool? ?? false,
      storeName: fields[2] as String? ?? '',
      receiptFootnote: fields[3] as String? ?? '',
      customBindings: (() {
        final f4 = fields[4];
        if (f4 is! Map) return const <String, List<String>>{};
        return f4.map((k, v) {
          if (k is! String) return MapEntry(k.toString(), <String>[]);
          if (v is String) return MapEntry(k, [v]);
          if (v is List) {
            return MapEntry(k, v.whereType<String>().toList());
          }
          return MapEntry(k, <String>[]);
        });
      })(),
      taxEnabled: fields[5] as bool? ?? false,
      taxPercent: fields[6] as int? ?? 0,
      autoPrintEnabled: fields[7] as bool? ?? false,
      orderCounter: fields[8] as int? ?? 0,
      lastOrderDate: fields[9] as String? ?? '',
      exportDirectoryPath: fields[10] as String? ?? '',
      saveReceiptAsImage: fields[11] as bool? ?? false,
      saveReceiptAsPdf: numFields > 33
          ? (fields[34] is bool ? fields[34] as bool : false)
          : false,
      storeAddress: fields[12] as String? ?? '',
      storePhoneNumber: fields[13] as String? ?? '',
      logoSvgData: fields[14] as String?,
      receiptPrinterName: fields[15] as String?,
      barcodePrinterName: fields[16] as String?,
      barcodeActionPreference: fields[17] as String? ?? 'printDirect',
      shownPaymentTypeIds: numFields >= 21
          ? (fields[20] is List
                ? (fields[20] as List).cast<String>()
                : const [])
          : numFields == 19
          ? (fields[18] is List
                ? (fields[18] as List).cast<String>()
                : const [])
          : const [],
      businessType: numFields >= 20
          ? (fields[18] is String ? fields[18] as String : 'retail')
          : 'retail',
      minimumGameCost: numFields > 19 ? fields[19] as int? ?? 500 : 500,
      favoritesStripEnabled: numFields > 21
          ? fields[21] as bool? ?? false
          : false,
      roomsEnabled: numFields > 22 ? fields[22] as bool? ?? false : false,
      serviceChargeEnabled: numFields > 23
          ? fields[23] as bool? ?? false
          : false,
      serviceChargePercent: numFields > 24 ? fields[24] as int? ?? 12 : 12,
      minChargeEnabled: numFields > 25 ? fields[25] as bool? ?? false : false,
      minChargePerTablePiastres: numFields > 26 ? fields[26] as int? ?? 0 : 0,
      kitchenTicketsEnabled: numFields > 27
          ? fields[27] as bool? ?? true
          : true,
      kitchenPrinterName: numFields > 28 ? fields[28] as String? : null,
      barTicketsEnabled: numFields > 29 ? fields[29] as bool? ?? true : true,
      barPrinterName: numFields > 30 ? fields[30] as String? : null,
      shishaTicketsEnabled: numFields > 31 ? fields[31] as bool? ?? true : true,
      shishaPrinterName: numFields > 32 ? fields[32] as String? : null,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer.writeByte(34);
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
    writer.write(obj.logoSvgData);
    writer.writeByte(15);
    writer.write(obj.receiptPrinterName);
    writer.writeByte(16);
    writer.write(obj.barcodePrinterName);
    writer.writeByte(17);
    writer.write(obj.barcodeActionPreference);
    writer.writeByte(18);
    writer.write(obj.businessType);
    writer.writeByte(19);
    writer.write(obj.minimumGameCost);
    writer.writeByte(20);
    writer.write(obj.shownPaymentTypeIds);
    writer.writeByte(21);
    writer.write(obj.favoritesStripEnabled);
    writer.writeByte(22);
    writer.write(obj.roomsEnabled);
    writer.writeByte(23);
    writer.write(obj.serviceChargeEnabled);
    writer.writeByte(24);
    writer.write(obj.serviceChargePercent);
    writer.writeByte(25);
    writer.write(obj.minChargeEnabled);
    writer.writeByte(26);
    writer.write(obj.minChargePerTablePiastres);
    writer.writeByte(27);
    writer.write(obj.kitchenTicketsEnabled);
    writer.writeByte(28);
    writer.write(obj.kitchenPrinterName);
    writer.writeByte(29);
    writer.write(obj.barTicketsEnabled);
    writer.writeByte(30);
    writer.write(obj.barPrinterName);
    writer.writeByte(31);
    writer.write(obj.shishaTicketsEnabled);
    writer.writeByte(32);
    writer.write(obj.shishaPrinterName);
    writer.writeByte(34);
    writer.write(obj.saveReceiptAsPdf);
  }
}
