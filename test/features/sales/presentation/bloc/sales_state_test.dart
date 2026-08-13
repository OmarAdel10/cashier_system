import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';

void main() {
  group('MonthGroupedData', () {
    final dayGroup = DayGroup(
      date: DateTime(2026, 3, 15),
      cashiers: [
        CashierDayGroup(
          username: 'cashier1',
          shifts: [
            ShiftGroup(
              shiftId: 's1',
              startedAt: DateTime(2026, 3, 15, 9, 0),
              endedAt: DateTime(2026, 3, 15, 17, 0),
            ),
          ],
        ),
      ],
    );

    test('equality with same fields', () {
      final a = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
      );
      final b = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
      );

      expect(a, equals(b));
    });

    test('inequality with different year', () {
      final a = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
      );
      final b = MonthGroupedData(
        year: 2025,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
      );

      expect(a, isNot(equals(b)));
    });

    test('equality includes days list', () {
      final sharedDays = [dayGroup];
      final a = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 0,
        receiptCount: 1,
        days: sharedDays,
      );
      final b = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 0,
        receiptCount: 1,
        days: sharedDays,
      );

      expect(a, equals(b));
    });

    test('default days is empty list', () {
      const data = MonthGroupedData(
        year: 2026,
        month: 1,
        totalPiastres: 0,
        receiptCount: 0,
      );

      expect(data.days, isEmpty);
    });

    test('default itemsSold is zero', () {
      const data = MonthGroupedData(
        year: 2026,
        month: 1,
        totalPiastres: 0,
        receiptCount: 0,
      );

      expect(data.itemsSold, equals(0));
    });

    test('inequality with different itemsSold', () {
      const a = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
      );
      const b = MonthGroupedData(
        year: 2026,
        month: 3,
        totalPiastres: 10000,
        receiptCount: 5,
        itemsSold: 10,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('ShiftGroup', () {
    test('equality', () {
      final a = ShiftGroup(shiftId: 's1', startedAt: DateTime(2026, 1, 1));
      final b = ShiftGroup(shiftId: 's1', startedAt: DateTime(2026, 1, 1));

      expect(a, equals(b));
    });

    test('inequality with different shiftId', () {
      final a = ShiftGroup(shiftId: 's1', startedAt: DateTime(2026, 1, 1));
      final b = ShiftGroup(shiftId: 's2', startedAt: DateTime(2026, 1, 1));

      expect(a, isNot(equals(b)));
    });
  });

  group('CashierDayGroup', () {
    test('equality', () {
      final a = CashierDayGroup(username: 'cashier1');
      final b = CashierDayGroup(username: 'cashier1');

      expect(a, equals(b));
    });

    test('inequality with different username', () {
      final a = CashierDayGroup(username: 'cashier1');
      final b = CashierDayGroup(username: 'cashier2');

      expect(a, isNot(equals(b)));
    });
  });

  group('DayGroup', () {
    test('equality', () {
      final a = DayGroup(date: DateTime(2026, 3, 15));
      final b = DayGroup(date: DateTime(2026, 3, 15));

      expect(a, equals(b));
    });

    test('inequality with different date', () {
      final a = DayGroup(date: DateTime(2026, 3, 15));
      final b = DayGroup(date: DateTime(2026, 3, 16));

      expect(a, isNot(equals(b)));
    });
  });

  group('SalesState', () {
    test('default months is empty list', () {
      const state = SalesState();

      expect(state.months, isEmpty);
    });

    test('copyWith clearMonths clears months list', () {
      const state = SalesState(
        months: [
          MonthGroupedData(
            year: 2026,
            month: 1,
            totalPiastres: 0,
            receiptCount: 0,
          ),
        ],
      );
      final cleared = state.copyWith(clearMonths: true);

      expect(cleared.months, isEmpty);
    });

    test('hashCode consistent with equality', () {
      const a = SalesState(status: SalesStatus.ready);
      const b = SalesState(status: SalesStatus.ready);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('SalesState defaults expense sums to zero', () {
      const state = SalesState();
      expect(state.todayExpensesPiastres, 0);
      expect(state.monthlyExpensesPiastres, 0);
      expect(state.shiftExpensesPiastres, 0);
    });

    test('SalesState copyWith updates expense sums', () {
      final state = SalesState();
      final copy = state.copyWith(
        todayExpensesPiastres: 100,
        monthlyExpensesPiastres: 250,
        shiftExpensesPiastres: 75,
      );
      expect(copy.todayExpensesPiastres, 100);
      expect(copy.monthlyExpensesPiastres, 250);
      expect(copy.shiftExpensesPiastres, 75);
      expect(copy == state, isFalse);
    });
  });

  group('DayGroup', () {
    test('defaults expensesPiastres to zero and copyWith updates it', () {
      final day = DayGroup(date: DateTime(2026, 8, 11), cashiers: const []);
      expect(day.expensesPiastres, 0);
      final copy = day.copyWith(expensesPiastres: 300);
      expect(copy.expensesPiastres, 300);
    });
  });
}
