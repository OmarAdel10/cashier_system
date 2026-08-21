import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

void main() {
  group('AppTableOrderLineModel', () {
    test('should be a TableOrderLine', () {
      const model = AppTableOrderLineModel(name: 'Cola');

      expect(model, isA<TableOrderLine>());
      expect(model.prepCategory, PrepCategory.food);
    });
  });

  group('AppTableOrderLineModelAdapter', () {
    late Box<AppTableOrderLineModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppTableOrderLineModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppTableOrderLineModel>('test_table_lines');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_table_lines');
    });

    test('should have typeId 12', () {
      expect(AppTableOrderLineModelAdapter().typeId, 12);
    });

    test('should persist full line via Hive', () async {
      const model = AppTableOrderLineModel(
        name: 'Shisha Double Apple',
        barcode: '3003',
        quantity: 2,
        unitPricePiastres: 10000,
        prepCategory: PrepCategory.shisha,
      );

      await box.put('line_1', model);
      final retrieved = box.get('line_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Shisha Double Apple');
      expect(retrieved.barcode, '3003');
      expect(retrieved.quantity, 2);
      expect(retrieved.unitPricePiastres, 10000);
      expect(retrieved.prepCategory, PrepCategory.shisha);
    });

    test('legacy 4-field frames hydrate prepCategory to food', () async {
      Hive.registerAdapter<AppTableOrderLineModel>(
        _LegacyWritingAdapter(),
        override: true,
      );
      final legacyBox = await Hive.openBox<AppTableOrderLineModel>(
        'test_table_lines_legacy',
      );
      await legacyBox.put(
        'line_legacy',
        const AppTableOrderLineModel(
          name: 'Cola',
          barcode: '2002',
          quantity: 1,
          unitPricePiastres: 1500,
        ),
      );
      await legacyBox.close();

      Hive.registerAdapter<AppTableOrderLineModel>(
        AppTableOrderLineModelAdapter(),
        override: true,
      );
      final upgradedBox = await Hive.openBox<AppTableOrderLineModel>(
        'test_table_lines_legacy',
      );
      final retrieved = upgradedBox.get('line_legacy');

      expect(retrieved, isNotNull);
      expect(retrieved!.prepCategory, PrepCategory.food);
      expect(retrieved.name, 'Cola');
      await upgradedBox.close();
      await Hive.deleteBoxFromDisk('test_table_lines_legacy');
    });
  });
}

class _LegacyWritingAdapter extends AppTableOrderLineModelAdapter {
  @override
  void write(BinaryWriter writer, AppTableOrderLineModel obj) {
    writer.writeByte(4);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.barcode);
    writer.writeByte(2);
    writer.write(obj.quantity);
    writer.writeByte(3);
    writer.write(obj.unitPricePiastres);
  }
}
