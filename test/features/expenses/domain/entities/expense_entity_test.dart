import 'package:cashier_system/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line1 = ExpenseLineEntity(
    barcode: '111',
    name: 'Bread',
    quantity: 2,
    costPiastres: 1500,
  );
  const line2 = ExpenseLineEntity(
    barcode: '222',
    name: 'Oil',
    quantity: 1,
    costPiastres: 7500,
  );
  final expense = ExpenseEntity(
    id: 'exp-1',
    shiftId: 's1',
    username: 'cashier1',
    lines: const [line1, line2],
    createdAt: DateTime(2026, 8, 11, 10, 30),
  );

  group('ExpenseLineEntity', () {
    test('copyWith overrides only provided fields', () {
      expect(
        line1.copyWith(quantity: 5),
        const ExpenseLineEntity(
          barcode: '111',
          name: 'Bread',
          quantity: 5,
          costPiastres: 1500,
        ),
      );
      expect(
        line2.copyWith(costPiastres: 8000),
        const ExpenseLineEntity(
          barcode: '222',
          name: 'Oil',
          quantity: 1,
          costPiastres: 8000,
        ),
      );
    });

    test('equality compares all fields', () {
      expect(
        line1,
        const ExpenseLineEntity(
          barcode: '111',
          name: 'Bread',
          quantity: 2,
          costPiastres: 1500,
        ),
      );
      expect(line1 == line2, isFalse);
      expect(
        line1.hashCode,
        const ExpenseLineEntity(
          barcode: '111',
          name: 'Bread',
          quantity: 2,
          costPiastres: 1500,
        ).hashCode,
      );
    });

    test('toString includes fields', () {
      expect(line1.toString(), contains('barcode: 111'));
      expect(line1.toString(), contains('costPiastres: 1500'));
    });
  });

  group('ExpenseEntity', () {
    test('totalPiastres sums quantity x costPiastres over all lines', () {
      expect(expense.totalPiastres, 2 * 1500 + 1 * 7500);
    });

    test('totalPiastres is zero for empty lines', () {
      expect(
        ExpenseEntity(
          id: 'e',
          shiftId: 's',
          username: 'u',
          lines: [],
          createdAt: DateTime(2026),
        ).totalPiastres,
        0,
      );
    });

    test('copyWith overrides only provided fields', () {
      final copy = expense.copyWith(username: 'admin', lines: const [line1]);
      expect(copy.username, 'admin');
      expect(copy.id, 'exp-1');
      expect(copy.lines, const [line1]);
      expect(copy.shiftId, 's1');
    });

    test('equality compares all fields', () {
      final same = ExpenseEntity(
        id: 'exp-1',
        shiftId: 's1',
        username: 'cashier1',
        lines: const [line1, line2],
        createdAt: DateTime(2026, 8, 11, 10, 30),
      );
      expect(expense, same);
      expect(expense == expense.copyWith(username: 'x'), isFalse);
      expect(expense.hashCode, same.hashCode);
    });

    test('toString includes id and lines count', () {
      expect(expense.toString(), contains('exp-1'));
      expect(expense.toString(), contains('2 lines'));
    });

    test('orderNumber uses name when present', () {
      final named = ExpenseEntity(
        id: 'exp-1',
        shiftId: 's1',
        username: 'cashier1',
        lines: const [line1],
        createdAt: DateTime(2026, 8, 11, 10, 30),
        name: '  Grocery run  ',
      );
      expect(named.orderNumber, 'Grocery run');
    });

    test('orderNumber falls back to short id for legacy rows', () {
      expect(expense.orderNumber, 'EXP-EXP-1');
      expect(
        ExpenseEntity(
          id: 'ab',
          shiftId: 's',
          username: 'u',
          lines: const [],
          createdAt: DateTime(2026),
        ).orderNumber,
        'EXP-AB',
      );
    });
  });
}
