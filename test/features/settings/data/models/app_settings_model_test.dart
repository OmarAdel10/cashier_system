import 'package:cashier_system/features/settings/data/models/app_settings_model.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('AppSettingsModelAdapter', () {
    late Box<AppSettingsModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppSettingsModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppSettingsModel>('test_settings');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_settings');
    });

    test('persists and retrieves includeTaxInProfit', () async {
      final settings = const AppSettingsModel(
        includeTaxInProfit: false,
        taxEnabled: true,
        taxPercent: 14,
      );

      await box.put('settings', settings);
      final retrieved = box.get('settings');

      expect(retrieved, isNotNull);
      expect(retrieved!.includeTaxInProfit, isFalse);
      expect(retrieved.taxPercent, 14);
    });

    test('defaults includeTaxInProfit to true', () {
      const model = AppSettingsModel();
      expect(model.includeTaxInProfit, isTrue);
    });

    test('toEntity round-trips includeTaxInProfit', () {
      const model = AppSettingsModel(includeTaxInProfit: false);
      final entity = model.toEntity();
      expect(entity.includeTaxInProfit, isFalse);
    });

    test('entity defaults includeTaxInProfit to true', () {
      const entity = AppSettingsEntity();
      expect(entity.includeTaxInProfit, isTrue);
    });
  });
}
