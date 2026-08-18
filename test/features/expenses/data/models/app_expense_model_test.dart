import 'package:cashier_system/features/expenses/data/models/app_expense_model.dart';
import 'package:cashier_system/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppExpenseModelAdapter());
  });

  group('AppExpenseModel json', () {
    final now = DateTime(2026, 8, 11, 10, 30);
    final model = AppExpenseModel(
      id: 'exp-1',
      shiftId: 's1',
      username: 'cashier1',
      lines: const [
        ExpenseLineEntity(
          barcode: '111',
          name: 'Bread',
          quantity: 2,
          costPiastres: 1500,
        ),
        ExpenseLineEntity(
          barcode: '222',
          name: 'Oil',
          quantity: 1,
          costPiastres: 7500,
        ),
      ],
      createdAt: now,
      name: 'Grocery run',
    );

    test('toJson serializes all fields', () {
      final json = model.toJson();
      expect(json['id'], 'exp-1');
      expect(json['shiftId'], 's1');
      expect(json['username'], 'cashier1');
      expect((json['lines'] as List).length, 2);
      expect((json['lines'] as List).first['barcode'], '111');
      expect((json['lines'] as List).first['costPiastres'], 1500);
      expect(json['createdAt'], now.toIso8601String());
      expect(json['name'], 'Grocery run');
    });

    test('fromJson roundtrips', () {
      final decoded = AppExpenseModel.fromJson(model.toJson());
      expect(decoded.id, 'exp-1');
      expect(decoded.shiftId, 's1');
      expect(decoded.username, 'cashier1');
      expect(decoded.lines.length, 2);
      expect(decoded.lines[1].name, 'Oil');
      expect(decoded.lines[1].costPiastres, 7500);
      expect(decoded.createdAt, now);
      expect(decoded.totalPiastres, 10500);
      expect(decoded.name, 'Grocery run');
    });

    test('toEntity preserves fields', () {
      final entity = model.toEntity();
      expect(entity, isA<ExpenseEntity>());
      expect(entity.id, 'exp-1');
      expect(entity.lines.length, 2);
      expect(entity.totalPiastres, 2 * 1500 + 1 * 7500);
      expect(entity.name, 'Grocery run');
    });

    test('fromJson tolerates missing keys', () {
      final decoded = AppExpenseModel.fromJson(const {});
      expect(decoded.id, '');
      expect(decoded.shiftId, '');
      expect(decoded.username, '');
      expect(decoded.lines, isEmpty);
      expect(decoded.createdAt, isA<DateTime>());
      expect(decoded.name, '');
    });
  });

  group('AppExpenseModelAdapter hive roundtrip', () {
    test('binary roundtrip preserves every field', () async {
      final box = await Hive.openLazyBox<AppExpenseModel>('test_expense_model');
      final original = AppExpenseModel(
        id: 'exp-9',
        shiftId: 's9',
        username: 'admin',
        lines: const [
          ExpenseLineEntity(
            barcode: 'b1',
            name: 'Tea',
            quantity: 3,
            costPiastres: 1000,
          ),
        ],
        createdAt: DateTime(2026, 8, 11, 9, 0, 0, 123),
        name: 'Tea restock',
      );
      await box.put(original.id, original);
      final loaded = await box.get('exp-9');
      expect(loaded, isNotNull);
      expect(loaded!.id, original.id);
      expect(loaded.shiftId, 's9');
      expect(loaded.username, 'admin');
      expect(loaded.lines.length, 1);
      expect(loaded.lines.first.barcode, 'b1');
      expect(loaded.lines.first.quantity, 3);
      expect(loaded.lines.first.costPiastres, 1000);
      expect(loaded.createdAt, original.createdAt);
      expect(loaded.name, 'Tea restock');
      await box.close();
      await Hive.deleteBoxFromDisk('test_expense_model');
    });
  });
}
