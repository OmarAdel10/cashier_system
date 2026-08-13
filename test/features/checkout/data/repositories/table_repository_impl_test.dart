import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_model.dart';
import 'package:cashier_system/features/checkout/data/repositories/table_repository_impl.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';

void main() {
  group('TableRepositoryImpl', () {
    late Box<AppTableModel> box;
    late TableRepositoryImpl repo;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppTableModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppTableModel>('test_tables_repo');
      repo = TableRepositoryImpl(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_tables_repo');
    });

    test('should save and get tables', () async {
      const table = TableEntity(
        id: 't1',
        name: 'T1',
        zoneId: 'z1',
        capacity: 4,
      );

      final saveResult = await repo.saveTable(table);
      final getResult = await repo.getTables();

      expect(saveResult.fold((_) => false, (_) => true), true);

      final tables = getResult.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(tables.length, 1);
      expect(tables.first.name, 'T1');
      expect(tables.first.zoneId, 'z1');
    });

    test('should get single table by id', () async {
      await repo.saveTable(const TableEntity(id: 't1', name: 'T1'));

      final result = await repo.getTable('t1');

      final table = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(table, isNotNull);
      expect(table!.id, 't1');
    });

    test('should return null for missing table', () async {
      final result = await repo.getTable('missing');

      final table = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(table, isNull);
    });

    test('should delete table', () async {
      await repo.saveTable(const TableEntity(id: 't1', name: 'T1'));

      final result = await repo.deleteTable('t1');

      expect(result.fold((_) => false, (_) => true), true);
      final tables = (await repo.getTables()).fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(tables, isEmpty);
    });

    test('updateTableStatus should clear session fields when null', () async {
      final opened = DateTime(2026, 8, 9, 12, 0);
      await repo.saveTable(
        TableEntity(
          id: 't1',
          name: 'T1',
          status: TableStatus.occupied,
          tabOpenedAt: opened,
          activeRoundNumber: 2,
        ),
      );

      final result = await repo.updateTableStatus(
        't1',
        TableStatus.available,
        tabOpenedAt: null,
        activeRoundNumber: null,
      );

      expect(result.fold((_) => false, (_) => true), true);
      final table = (await repo.getTable(
        't1',
      )).fold((f) => fail('unexpected failure: $f'), (v) => v);
      expect(table!.status, TableStatus.available);
      expect(table.tabOpenedAt, isNull);
      expect(table.activeRoundNumber, isNull);
    });

    test('updateTableStatus should keep session fields when unset', () async {
      final opened = DateTime(2026, 8, 9, 12, 0);
      await repo.saveTable(
        TableEntity(
          id: 't1',
          name: 'T1',
          status: TableStatus.occupied,
          tabOpenedAt: opened,
          activeRoundNumber: 2,
        ),
      );

      final result = await repo.updateTableStatus('t1', TableStatus.served);

      expect(result.fold((_) => false, (_) => true), true);
      final table = (await repo.getTable(
        't1',
      )).fold((f) => fail('unexpected failure: $f'), (v) => v);
      expect(table!.status, TableStatus.served);
      expect(table.tabOpenedAt, opened);
      expect(table.activeRoundNumber, 2);
    });

    test('updateTableStatus should fail for missing table', () async {
      final result = await repo.updateTableStatus(
        'missing',
        TableStatus.occupied,
      );

      final failure = result.fold<Failure?>((f) => f, (_) => null);
      expect(failure, isA<DatabaseFailure>());
    });
  });
}
