import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/settings/data/models/app_settings_model.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  group('AppSettingsModel', () {
    group('fromJson', () {
      test('should return a valid model with all fields', () {
        final json = {
          'languageCode': 'en',
          'isDarkMode': true,
          'storeName': 'Test Store',
          'receiptFootnote': 'Thank you for your purchase!',
          'businessType': 'cafe',
          'minimumGameCost': 1000,
        };

        final model = AppSettingsModel.fromJson(json);

        expect(model.languageCode, 'en');
        expect(model.isDarkMode, true);
        expect(model.storeName, 'Test Store');
        expect(model.receiptFootnote, 'Thank you for your purchase!');
        expect(model.businessType, 'cafe');
        expect(model.minimumGameCost, 1000);
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final model = AppSettingsModel.fromJson(json);

        expect(model.languageCode, 'ar');
        expect(model.isDarkMode, false);
        expect(model.storeName, '');
        expect(model.receiptFootnote, '');
        expect(model.businessType, 'retail');
        expect(model.minimumGameCost, 500);
      });
    });

    group('toJson', () {
      test('should return a valid JSON map', () {
        const model = AppSettingsModel(
          languageCode: 'en',
          isDarkMode: true,
          storeName: 'Test Store',
          receiptFootnote: 'Thank you!',
        );

        final json = model.toJson();

        expect(json['languageCode'], 'en');
        expect(json['isDarkMode'], true);
        expect(json['storeName'], 'Test Store');
        expect(json['receiptFootnote'], 'Thank you!');
      });

      test('should include businessType and minimumGameCost in JSON map', () {
        const model = AppSettingsModel(
          businessType: 'cafe',
          minimumGameCost: 1000,
        );

        final json = model.toJson();

        expect(json['businessType'], 'cafe');
        expect(json['minimumGameCost'], 1000);
      });
    });

    group('round-trip', () {
      test('should serialize and deserialize correctly', () {
        const original = AppSettingsModel(
          languageCode: 'ar',
          isDarkMode: true,
          storeName: 'مكتبة النزهة',
          receiptFootnote: 'نشكركم على ثقتكم',
        );

        final json = original.toJson();
        final decoded = AppSettingsModel.fromJson(json);

        expect(decoded.languageCode, original.languageCode);
        expect(decoded.isDarkMode, original.isDarkMode);
        expect(decoded.storeName, original.storeName);
        expect(decoded.receiptFootnote, original.receiptFootnote);
      });

      test('should round-trip businessType and minimumGameCost', () {
        const original = AppSettingsModel(
          businessType: 'cafe',
          minimumGameCost: 1500,
        );

        final json = original.toJson();
        final decoded = AppSettingsModel.fromJson(json);

        expect(decoded.businessType, 'cafe');
        expect(decoded.minimumGameCost, 1500);
      });

      test('should round-trip via toEntity', () {
        const model = AppSettingsModel(
          businessType: 'game',
          minimumGameCost: 750,
        );

        final entity = model.toEntity();

        expect(entity, isA<AppSettingsEntity>());
        expect(entity.businessType, 'game');
        expect(entity.minimumGameCost, 750);
      });
    });

    group('adapter round-trip', () {
      late Box<AppSettingsModel> box;

      setUpAll(() async {
        Hive.init('test/_hive_test');
        Hive.registerAdapter(AppSettingsModelAdapter());
      });

      setUp(() async {
        box = await Hive.openBox<AppSettingsModel>('test_app_settings_model');
      });

      tearDown(() async {
        await box.close();
        await Hive.deleteBoxFromDisk('test_app_settings_model');
      });

      test(
        'should persist and retrieve businessType and minimumGameCost',
        () async {
          await box.put(
            'settings',
            const AppSettingsModel(businessType: 'cafe', minimumGameCost: 1000),
          );

          final retrieved = box.get('settings');

          expect(retrieved, isNotNull);
          expect(retrieved!.businessType, 'cafe');
          expect(retrieved.minimumGameCost, 1000);
        },
      );

      test('should hydrate legacy 18-field frames with defaults', () async {
        Hive.registerAdapter<AppSettingsModel>(_LegacyWritingAdapter(), override: true);
        final legacyBox =
            await Hive.openBox<AppSettingsModel>('test_app_settings_legacy');
        await legacyBox.put(
          'settings',
          const AppSettingsModel(storeName: 'Legacy Store'),
        );
        await legacyBox.close();

        Hive.registerAdapter<AppSettingsModel>(
          AppSettingsModelAdapter(),
          override: true,
        );
        final upgradedBox =
            await Hive.openBox<AppSettingsModel>('test_app_settings_legacy');
        final retrieved = upgradedBox.get('settings');

        expect(retrieved, isNotNull);
        expect(retrieved!.businessType, 'retail');
        expect(retrieved.minimumGameCost, 500);
        expect(retrieved.storeName, 'Legacy Store');
        await upgradedBox.close();
        await Hive.deleteBoxFromDisk('test_app_settings_legacy');
      });
    });

    group('identity', () {
      test('should be an AppSettingsEntity', () {
        const model = AppSettingsModel();
        expect(model, isA<AppSettingsEntity>());
      });
    });
  });
}

class _LegacyWritingAdapter extends AppSettingsModelAdapter {
  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer.writeByte(18);
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
  }
}
