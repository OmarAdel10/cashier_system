import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';

void main() {
  group('AppTableModel', () {
    test('should be a TableEntity', () {
      const model = AppTableModel(id: 't1', name: 'T1');

      expect(model, isA<TableEntity>());
      expect(model.status, TableStatus.available);
    });
  });

  group('AppTableModelAdapter', () {
    late Box<AppTableModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppTableModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppTableModel>('test_tables');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_tables');
    });

    test('should have typeId 9', () {
      expect(AppTableModelAdapter().typeId, 9);
    });

    test('should persist full model via Hive', () async {
      final model = AppTableModel(
        id: 't1',
        name: 'T1',
        zoneId: 'z1',
        capacity: 4,
        isRoom: true,
        hourlyRatePiastres: 5000,
        status: TableStatus.served,
        tabOpenedAt: DateTime(2026, 8, 9, 12, 0),
        activeRoundNumber: 3,
      );

      await box.put('table_1', model);
      final retrieved = box.get('table_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 't1');
      expect(retrieved.name, 'T1');
      expect(retrieved.zoneId, 'z1');
      expect(retrieved.capacity, 4);
      expect(retrieved.isRoom, true);
      expect(retrieved.hourlyRatePiastres, 5000);
      expect(retrieved.status, TableStatus.served);
      expect(retrieved.tabOpenedAt, DateTime(2026, 8, 9, 12, 0));
      expect(retrieved.activeRoundNumber, 3);
    });

    test('should preserve null activeRoundNumber via Hive', () async {
      const model = AppTableModel(
        id: 't2',
        name: 'T2',
        status: TableStatus.occupied,
        tabOpenedAt: null,
        activeRoundNumber: null,
      );

      await box.put('table_2', model);
      final retrieved = box.get('table_2');

      expect(retrieved, isNotNull);
      expect(retrieved!.tabOpenedAt, isNull);
      expect(retrieved.activeRoundNumber, isNull);
    });

    test('legacy 8-field frames hydrate defaults', () async {
      Hive.registerAdapter<AppTableModel>(
        _LegacyWritingAdapter(),
        override: true,
      );
      final legacyBox = await Hive.openBox<AppTableModel>('test_tables_legacy');
      await legacyBox.put(
        'table_legacy',
        const AppTableModel(id: 't9', name: 'T9', zoneId: 'z1'),
      );
      await legacyBox.close();

      Hive.registerAdapter<AppTableModel>(
        AppTableModelAdapter(),
        override: true,
      );
      final upgradedBox = await Hive.openBox<AppTableModel>(
        'test_tables_legacy',
      );
      final retrieved = upgradedBox.get('table_legacy');

      expect(retrieved, isNotNull);
      expect(retrieved!.status, TableStatus.available);
      expect(retrieved.isRoom, false);
      expect(retrieved.tabOpenedAt, isNull);
      expect(retrieved.activeRoundNumber, isNull);
      await upgradedBox.close();
      await Hive.deleteBoxFromDisk('test_tables_legacy');
    });
  });
}

class _LegacyWritingAdapter extends AppTableModelAdapter {
  @override
  void write(BinaryWriter writer, AppTableModel obj) {
    writer.writeByte(8);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.zoneId);
    writer.writeByte(3);
    writer.write(obj.capacity);
    writer.writeByte(4);
    writer.write(obj.isRoom);
    writer.writeByte(5);
    writer.write(obj.hourlyRatePiastres);
    writer.writeByte(6);
    writer.write(obj.status.index);
    writer.writeByte(7);
    writer.write(obj.tabOpenedAt);
  }
}
