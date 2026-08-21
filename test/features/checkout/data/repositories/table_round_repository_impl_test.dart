import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_order_line_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_round_model.dart';
import 'package:cashier_system/features/checkout/data/repositories/table_round_repository_impl.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_round_entity.dart';

void main() {
  group('TableRoundRepositoryImpl', () {
    late Box<AppTableRoundModel> box;
    late TableRoundRepositoryImpl repo;

    final round1 = TableRoundEntity(
      id: 'r1',
      tableId: 't1',
      roundNumber: 1,
      lines: const [
        AppTableOrderLineModel(
          name: 'Cola',
          quantity: 2,
          unitPricePiastres: 1500,
          prepCategory: PrepCategory.beverage,
        ),
      ],
      firedAt: DateTime(2026, 8, 9, 14, 30),
    );
    final round2 = TableRoundEntity(
      id: 'r2',
      tableId: 't1',
      roundNumber: 2,
      lines: const [],
      firedAt: DateTime(2026, 8, 9, 15, 0),
    );
    final round3 = TableRoundEntity(
      id: 'r3',
      tableId: 't2',
      roundNumber: 1,
      lines: const [],
      firedAt: DateTime(2026, 8, 9, 15, 30),
    );

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppTableOrderLineModelAdapter());
      Hive.registerAdapter(AppTableRoundModelAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<AppTableRoundModel>('test_rounds_repo');
      repo = TableRoundRepositoryImpl(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_rounds_repo');
    });

    test('should save and get all rounds', () async {
      await repo.saveRound(round1);
      await repo.saveRound(round3);

      final result = await repo.getRounds();

      final rounds = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(rounds.length, 2);
    });

    test('should get rounds for a specific table', () async {
      await repo.saveRound(round1);
      await repo.saveRound(round2);
      await repo.saveRound(round3);

      final result = await repo.getRoundsForTable('t1');

      final rounds = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(rounds.length, 2);
      expect(rounds.every((r) => r.tableId == 't1'), true);
    });

    test('should delete a round', () async {
      await repo.saveRound(round1);
      await repo.saveRound(round2);

      final result = await repo.deleteRound('r1');

      expect(result.fold((_) => false, (_) => true), true);
      final rounds = (await repo.getRounds()).fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      expect(rounds.length, 1);
      expect(rounds.single.id, 'r2');
    });

    test('round trip preserves lines and prepCategory', () async {
      await repo.saveRound(round1);

      final result = await repo.getRoundsForTable('t1');

      final rounds = result.fold(
        (f) => fail('unexpected failure: $f'),
        (v) => v,
      );
      final line = rounds.single.lines.single;
      expect(line.name, 'Cola');
      expect(line.quantity, 2);
      expect(line.unitPricePiastres, 1500);
      expect(line.prepCategory, PrepCategory.beverage);
      expect(rounds.single.firedAt, DateTime(2026, 8, 9, 14, 30));
    });
  });
}
