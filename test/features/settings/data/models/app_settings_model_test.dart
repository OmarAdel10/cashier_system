import 'package:flutter_test/flutter_test.dart';
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
        };

        final model = AppSettingsModel.fromJson(json);

        expect(model.languageCode, 'en');
        expect(model.isDarkMode, true);
        expect(model.storeName, 'Test Store');
        expect(model.receiptFootnote, 'Thank you for your purchase!');
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final model = AppSettingsModel.fromJson(json);

        expect(model.languageCode, 'ar');
        expect(model.isDarkMode, false);
        expect(model.storeName, '');
        expect(model.receiptFootnote, '');
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
    });

    group('identity', () {
      test('should be an AppSettingsEntity', () {
        const model = AppSettingsModel();
        expect(model, isA<AppSettingsEntity>());
      });
    });
  });
}
