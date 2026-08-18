import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_station_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('AppStationModelAdapter', () {
    late Box<AppStationModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppStationModelAdapter());
      Hive.registerAdapter(AppTableOrderLineModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppStationModel>('test_stations');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_stations');
    });

    test('should have typeId 7', () {
      expect(AppStationModelAdapter().typeId, 7);
    });

    test('should persist addon lines via Hive', () async {
      const model = AppStationModel(
        id: 'PS4-1',
        name: 'PS4-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50.0,
        multiHourlyRate: 75.0,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'assets/icons/ps.svg',
        status: StationStatus.active,
        addonLines: [
          AppTableOrderLineModel(
            name: 'Cola',
            barcode: 'PROD-1',
            quantity: 2,
            unitPricePiastres: 1500,
            prepCategory: PrepCategory.beverage,
          ),
        ],
      );

      await box.put('PS4-1', model);
      await box.close();
      box = await Hive.openBox<AppStationModel>('test_stations');
      final retrieved = box.get('PS4-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'PS4-1');
      expect(retrieved.status, StationStatus.active);
      expect(retrieved.addonLines, hasLength(1));
      expect(retrieved.addonLines.first.name, 'Cola');
      expect(retrieved.addonLines.first.barcode, 'PROD-1');
      expect(retrieved.addonLines.first.quantity, 2);
      expect(retrieved.addonLines.first.unitPricePiastres, 1500);
      expect(retrieved.addonLines.first.prepCategory, PrepCategory.beverage);
    });

    test('should fall back to empty addon lines when field missing', () async {
      const model = AppStationModel(
        id: 'PS4-2',
        name: 'PS4-2',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50.0,
        multiHourlyRate: 75.0,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: '',
      );

      await box.put('PS4-2', model);
      final retrieved = box.get('PS4-2');

      expect(retrieved, isNotNull);
      expect(retrieved!.addonLines, isEmpty);
    });

    test(
      'legacy over-counted frames open without crashing and recover fields',
      () async {
        AppStationModelAdapter.overreadDetected = false;
        Hive.registerAdapter<AppStationModel>(
          _LegacyWritingAdapter(),
          override: true,
        );
        final legacyBox = await Hive.openBox<AppStationModel>(
          'test_stations_legacy',
        );
        await legacyBox.put(
          'PS4-3',
          const AppStationModel(
            id: 'PS4-3',
            name: 'PS4-3',
            parentCategory: 'PS4',
            stationType: StationType.playstation,
            normalHourlyRate: 50.0,
            multiHourlyRate: 75.0,
            minimumGameCostNormal: 100,
            minimumGameCostMulti: 150,
            iconAsset: 'assets/icons/ps.svg',
            status: StationStatus.active,
            isFixedDuration: true,
            fixedDurationMinutes: 60,
            overtimeStartMinutes: 10,
            sessionTier: PricingTier.multi,
          ),
        );
        await legacyBox.close();

        Hive.registerAdapter<AppStationModel>(
          AppStationModelAdapter(),
          override: true,
        );
        final upgradedBox = await Hive.openBox<AppStationModel>(
          'test_stations_legacy',
        );
        final retrieved = upgradedBox.get('PS4-3');

        expect(retrieved, isNotNull);
        expect(retrieved!.name, 'PS4-3');
        expect(retrieved.stationType, StationType.playstation);
        expect(retrieved.normalHourlyRate, 50.0);
        expect(retrieved.multiHourlyRate, 75.0);
        expect(retrieved.isFixedDuration, isTrue);
        expect(retrieved.fixedDurationMinutes, 60);
        expect(retrieved.overtimeStartMinutes, 10);
        expect(retrieved.sessionTier, PricingTier.multi);
        expect(retrieved.addonLines, isEmpty);
        expect(AppStationModelAdapter.overreadDetected, isTrue);
        await upgradedBox.close();
        await Hive.deleteBoxFromDisk('test_stations_legacy');
        AppStationModelAdapter.overreadDetected = false;
      },
    );
  });
}

class _LegacyWritingAdapter extends AppStationModelAdapter {
  @override
  void write(BinaryWriter writer, AppStationModel obj) {
    writer.writeByte(16);
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
