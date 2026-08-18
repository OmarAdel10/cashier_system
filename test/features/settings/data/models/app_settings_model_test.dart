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

    test('round-trips all fields through disk reopen', () async {
      const settings = AppSettingsModel(
        languageCode: 'en',
        isDarkMode: true,
        storeName: 'My Store',
        receiptFootnote: 'Thanks!',
        customBindings: {
          'F4': ['print'],
          'F6': ['duplicate', 'save'],
        },
        taxEnabled: true,
        taxPercent: 14,
        autoPrintEnabled: true,
        orderCounter: 42,
        lastOrderDate: '2026-08-13',
        exportDirectoryPath: 'C:/exports',
        saveReceiptAsImage: true,
        storeAddress: 'Main St 1',
        storePhoneNumber: '012345',
        logoSvgData: '<svg/>',
        receiptPrinterName: 'RP-1',
        barcodePrinterName: 'BP-1',
        barcodeActionPreference: 'showDialog',
        shownPaymentTypeIds: ['cash', 'card'],
        businessType: 'arcade',
        minimumGameCost: 500,
        favoritesStripEnabled: true,
        roomsEnabled: true,
        serviceChargeEnabled: true,
        serviceChargePercent: 12,
        minChargeEnabled: true,
        minChargePerTablePiastres: 250,
        kitchenTicketsEnabled: true,
        kitchenPrinterName: 'KP-1',
        barTicketsEnabled: false,
        barPrinterName: 'BRP-1',
        shishaTicketsEnabled: true,
        shishaPrinterName: 'SP-1',
        includeTaxInProfit: false,
      );

      await box.put('settings', settings);
      await box.close();
      box = await Hive.openBox<AppSettingsModel>('test_settings');
      final retrieved = box.get('settings');

      expect(retrieved, isNotNull);
      expect(retrieved!.languageCode, 'en');
      expect(retrieved.isDarkMode, isTrue);
      expect(retrieved.storeName, 'My Store');
      expect(retrieved.receiptFootnote, 'Thanks!');
      expect(retrieved.customBindings['F4'], ['print']);
      expect(retrieved.customBindings['F6'], ['duplicate', 'save']);
      expect(retrieved.taxEnabled, isTrue);
      expect(retrieved.taxPercent, 14);
      expect(retrieved.autoPrintEnabled, isTrue);
      expect(retrieved.orderCounter, 42);
      expect(retrieved.lastOrderDate, '2026-08-13');
      expect(retrieved.exportDirectoryPath, 'C:/exports');
      expect(retrieved.saveReceiptAsImage, isTrue);
      expect(retrieved.storeAddress, 'Main St 1');
      expect(retrieved.storePhoneNumber, '012345');
      expect(retrieved.logoSvgData, '<svg/>');
      expect(retrieved.receiptPrinterName, 'RP-1');
      expect(retrieved.barcodePrinterName, 'BP-1');
      expect(retrieved.barcodeActionPreference, 'showDialog');
      expect(retrieved.shownPaymentTypeIds, ['cash', 'card']);
      expect(retrieved.businessType, 'arcade');
      expect(retrieved.minimumGameCost, 500);
      expect(retrieved.favoritesStripEnabled, isTrue);
      expect(retrieved.roomsEnabled, isTrue);
      expect(retrieved.serviceChargeEnabled, isTrue);
      expect(retrieved.serviceChargePercent, 12);
      expect(retrieved.minChargeEnabled, isTrue);
      expect(retrieved.minChargePerTablePiastres, 250);
      expect(retrieved.kitchenTicketsEnabled, isTrue);
      expect(retrieved.kitchenPrinterName, 'KP-1');
      expect(retrieved.barTicketsEnabled, isFalse);
      expect(retrieved.barPrinterName, 'BRP-1');
      expect(retrieved.shishaTicketsEnabled, isTrue);
      expect(retrieved.shishaPrinterName, 'SP-1');
      expect(retrieved.includeTaxInProfit, isFalse);
    });

    test(
      'legacy over-counted frames open without crashing and recover fields',
      () async {
        AppSettingsModelAdapter.overreadDetected = false;
        Hive.registerAdapter<AppSettingsModel>(
          _LegacyWritingAdapter(),
          override: true,
        );
        final legacyBox = await Hive.openBox<AppSettingsModel>(
          'test_settings_legacy',
        );
        await legacyBox.put(
          'settings',
          const AppSettingsModel(
            languageCode: 'ar',
            isDarkMode: true,
            storeName: 'Old Store',
            orderCounter: 7,
            businessType: 'restaurant',
            includeTaxInProfit: false,
            shownPaymentTypeIds: ['cash'],
          ),
        );
        await legacyBox.close();

        Hive.registerAdapter<AppSettingsModel>(
          AppSettingsModelAdapter(),
          override: true,
        );
        final upgradedBox = await Hive.openBox<AppSettingsModel>(
          'test_settings_legacy',
        );
        final retrieved = upgradedBox.get('settings');

        expect(retrieved, isNotNull);
        expect(retrieved!.storeName, 'Old Store');
        expect(retrieved.languageCode, 'ar');
        expect(retrieved.isDarkMode, isTrue);
        expect(retrieved.orderCounter, 7);
        expect(retrieved.businessType, 'restaurant');
        expect(retrieved.includeTaxInProfit, isFalse);
        expect(retrieved.shownPaymentTypeIds, ['cash']);
        expect(AppSettingsModelAdapter.overreadDetected, isTrue);
        await upgradedBox.close();
        await Hive.deleteBoxFromDisk('test_settings_legacy');
        AppSettingsModelAdapter.overreadDetected = false;
      },
    );

    test('toEntity round-trips includeTaxInProfit', () {
      const model = AppSettingsModel(includeTaxInProfit: false);
      final entity = model.toEntity();
      expect(entity.includeTaxInProfit, isFalse);
    });

    test('defaults includeTaxInProfit to true', () {
      const entity = AppSettingsEntity();
      expect(entity.includeTaxInProfit, isTrue);
    });
  });
}

class _LegacyWritingAdapter extends AppSettingsModelAdapter {
  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer.writeByte(35);
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
    writer.writeByte(33);
    writer.write(obj.includeTaxInProfit);
  }
}
