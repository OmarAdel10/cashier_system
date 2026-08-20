import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/settings/data/models/app_settings_model.dart';
import 'package:cashier_system/features/settings/data/repositories/settings_repository.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/domain/repositories/i_settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    late Box<AppSettingsModel> box;
    late ISettingsRepository repository;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppSettingsModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppSettingsModel>('test_settings');
      repository = SettingsRepository(
        box: box,
        defaultExportPathProvider: () async => '',
      );
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_settings');
    });

    AppSettingsEntity unwrap(Either<Failure, AppSettingsEntity> result) {
      return result.fold((failure) => throw failure, (settings) => settings);
    }

    group('getSettings', () {
      const testDownloads = r'C:\Users\Test\Downloads';

      SettingsRepository repoWithDownloads() {
        return SettingsRepository(
          box: box,
          defaultExportPathProvider: () async => testDownloads,
        );
      }

      test('should return defaults when box is empty', () async {
        final result = await repository.getSettings();
        final settings = unwrap(result);

        expect(settings.languageCode, 'ar');
        expect(settings.isDarkMode, false);
        expect(settings.storeName, '');
        expect(settings.receiptFootnote, 'Thanks');
      });

      test('should default export path to Downloads when box is empty', () async {
        final result = await repoWithDownloads().getSettings();
        final settings = unwrap(result);

        expect(settings.exportDirectoryPath, testDownloads);
      });

      test('should default export path to Downloads when saved path is empty',
          () async {
        await repository.saveSettings(
          const AppSettingsEntity(languageCode: 'en', storeName: 'X'),
        );

        final result = await repoWithDownloads().getSettings();
        final settings = unwrap(result);

        expect(settings.exportDirectoryPath, testDownloads);
        expect(settings.storeName, 'X');
      });

      test('should preserve a non-empty saved export path', () async {
        await repository.saveSettings(
          const AppSettingsEntity(
            languageCode: 'en',
            exportDirectoryPath: r'D:\Exports',
          ),
        );

        final result = await repoWithDownloads().getSettings();
        final settings = unwrap(result);

        expect(settings.exportDirectoryPath, r'D:\Exports');
      });

      test('should return saved settings when box has data', () async {
        const entity = AppSettingsEntity(
          languageCode: 'en',
          isDarkMode: true,
          storeName: 'Test Store',
          receiptFootnote: 'Thanks!',
        );
        await repository.saveSettings(entity);

        final result = await repository.getSettings();
        final retrieved = unwrap(result);

        expect(retrieved.languageCode, 'en');
        expect(retrieved.isDarkMode, true);
        expect(retrieved.storeName, 'Test Store');
        expect(retrieved.receiptFootnote, 'Thanks!');
      });
    });

    group('saveSettings', () {
      test('should persist settings and retrieve them correctly', () async {
        const entity = AppSettingsEntity(
          languageCode: 'ar',
          isDarkMode: true,
          storeName: 'مكتبة النزهة',
          receiptFootnote: 'شكراً لشرائكم',
          shownPaymentTypeIds: ['cash', 'instapay', 'visa'],
        );

        final saveResult = await repository.saveSettings(entity);
        expect(saveResult, isA<Right<Failure, void>>());

        final result = await repository.getSettings();
        final retrieved = unwrap(result);
        expect(retrieved, equals(entity));
      });

      test('should overwrite previous settings', () async {
        const first = AppSettingsEntity(
          languageCode: 'ar',
          storeName: 'Store A',
        );
        const second = AppSettingsEntity(
          languageCode: 'en',
          storeName: 'Store B',
        );

        await repository.saveSettings(first);
        await repository.saveSettings(second);

        final result = await repository.getSettings();
        final retrieved = unwrap(result);
        expect(retrieved.languageCode, 'en');
        expect(retrieved.storeName, 'Store B');
      });
    });
  });
}
