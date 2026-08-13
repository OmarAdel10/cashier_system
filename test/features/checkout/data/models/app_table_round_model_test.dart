import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_round_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('AppTableRoundModel', () {
    test('should be a TableRoundEntity', () {
      final model = AppTableRoundModel(
        id: 'r1',
        tableId: 't1',
        roundNumber: 1,
        lines: const [
          AppTableOrderLineModel(
            name: 'Cola',
            prepCategory: PrepCategory.beverage,
          ),
        ],
        firedAt: DateTime(2026, 8, 9, 14, 30),
      );

      expect(model, isA<TableRoundEntity>());
      expect(model.status, RoundStatus.pendingKitchen);
    });
  });

  group('AppTableRoundModelAdapter', () {
    late Box<AppTableRoundModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppTableOrderLineModelAdapter());
      Hive.registerAdapter(AppTableRoundModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppTableRoundModel>('test_table_rounds');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_table_rounds');
    });

    test('should have typeId 10', () {
      expect(AppTableRoundModelAdapter().typeId, 10);
    });

    test('should persist full round via Hive', () async {
      final model = AppTableRoundModel(
        id: 'r1',
        tableId: 't1',
        roundNumber: 2,
        lines: const [
          AppTableOrderLineModel(
            name: 'Chicken Sandwich',
            barcode: '1001',
            quantity: 2,
            unitPricePiastres: 7500,
            prepCategory: PrepCategory.food,
          ),
          AppTableOrderLineModel(
            name: 'Cola',
            barcode: '2002',
            quantity: 1,
            unitPricePiastres: 1500,
            prepCategory: PrepCategory.beverage,
          ),
        ],
        firedAt: DateTime(2026, 8, 9, 14, 30),
        status: RoundStatus.prepared,
      );

      await box.put('round_1', model);
      final retrieved = box.get('round_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'r1');
      expect(retrieved.tableId, 't1');
      expect(retrieved.roundNumber, 2);
      expect(retrieved.lines.length, 2);
      expect(retrieved.lines.first.name, 'Chicken Sandwich');
      expect(retrieved.lines.first.quantity, 2);
      expect(retrieved.lines.first.prepCategory, PrepCategory.food);
      expect(retrieved.lines.last.prepCategory, PrepCategory.beverage);
      expect(retrieved.firedAt, DateTime(2026, 8, 9, 14, 30));
      expect(retrieved.status, RoundStatus.prepared);
    });

    test('legacy 5-field frames hydrate defaults and empty lines', () async {
      Hive.registerAdapter<AppTableRoundModel>(
        _LegacyWritingAdapter(),
        override: true,
      );
      final legacyBox = await Hive.openBox<AppTableRoundModel>(
        'test_table_rounds_legacy',
      );
      await legacyBox.put(
        'round_legacy',
        AppTableRoundModel(
          id: 'r9',
          tableId: 't9',
          roundNumber: 1,
          lines: const [],
          firedAt: DateTime(2026, 8, 9, 14, 30),
        ),
      );
      await legacyBox.close();

      Hive.registerAdapter<AppTableRoundModel>(
        AppTableRoundModelAdapter(),
        override: true,
      );
      final upgradedBox = await Hive.openBox<AppTableRoundModel>(
        'test_table_rounds_legacy',
      );
      final retrieved = upgradedBox.get('round_legacy');

      expect(retrieved, isNotNull);
      expect(retrieved!.lines, isEmpty);
      expect(retrieved.status, RoundStatus.pendingKitchen);
      expect(retrieved.roundNumber, 1);
      await upgradedBox.close();
      await Hive.deleteBoxFromDisk('test_table_rounds_legacy');
    });
  });
}

class _LegacyWritingAdapter extends AppTableRoundModelAdapter {
  @override
  void write(BinaryWriter writer, AppTableRoundModel obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.tableId);
    writer.writeByte(2);
    writer.write(obj.roundNumber);
    writer.writeByte(3);
    writer.write(obj.lines);
    writer.writeByte(4);
    writer.write(obj.firedAt);
  }
}
