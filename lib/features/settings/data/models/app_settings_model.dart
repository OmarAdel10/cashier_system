import 'package:hive/hive.dart';
import '../../domain/entities/app_settings_entity.dart';

class AppSettingsModel extends AppSettingsEntity {
  const AppSettingsModel({
    super.languageCode,
    super.isDarkMode,
    super.storeName,
    super.receiptFootnote,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      languageCode: json['languageCode'] as String? ?? 'ar',
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      storeName: json['storeName'] as String? ?? '',
      receiptFootnote: json['receiptFootnote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languageCode': languageCode,
      'isDarkMode': isDarkMode,
      'storeName': storeName,
      'receiptFootnote': receiptFootnote,
    };
  }

  AppSettingsEntity toEntity() {
    return AppSettingsEntity(
      languageCode: languageCode,
      isDarkMode: isDarkMode,
      storeName: storeName,
      receiptFootnote: receiptFootnote,
    );
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
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.languageCode);
    writer.writeByte(1);
    writer.write(obj.isDarkMode);
    writer.writeByte(2);
    writer.write(obj.storeName);
    writer.writeByte(3);
    writer.write(obj.receiptFootnote);
  }
}
