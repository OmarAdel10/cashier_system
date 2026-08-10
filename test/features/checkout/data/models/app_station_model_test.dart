import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_station_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
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
          TableOrderLine(
            name: 'Cola',
            barcode: 'PROD-1',
            quantity: 2,
            unitPricePiastres: 1500,
            prepCategory: PrepCategory.beverage,
          ),
        ],
      );

      await box.put('PS4-1', model);
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
  });
}
