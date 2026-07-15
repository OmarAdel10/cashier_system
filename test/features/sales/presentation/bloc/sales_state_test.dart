import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';

void main() {
  group('MonthData', () {
    test('equality with same fields', () {
      final a = MonthData(year: 2026, month: 3, totalPiastres: 10000, receiptCount: 5);
      final b = MonthData(year: 2026, month: 3, totalPiastres: 10000, receiptCount: 5);

      expect(a, equals(b));
    });

    test('inequality with different year', () {
      final a = MonthData(year: 2026, month: 3, totalPiastres: 10000, receiptCount: 5);
      final b = MonthData(year: 2025, month: 3, totalPiastres: 10000, receiptCount: 5);

      expect(a, isNot(equals(b)));
    });

    test('equality includes receipts list', () {
      final receipt = ReceiptEntity(
        id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
        items: const [], subtotalPiastres: 0, totalPiastres: 0,
        createdAt: DateTime(2026, 1, 1), username: 'cashier1',
      );
      final sharedList = [receipt];
      final a = MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 1, receipts: sharedList);
      final b = MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 1, receipts: sharedList);

      expect(a, equals(b));
    });

    test('hashCode consistent with equality', () {
      final a = MonthData(year: 2026, month: 3, totalPiastres: 10000, receiptCount: 5);
      final b = MonthData(year: 2026, month: 3, totalPiastres: 10000, receiptCount: 5);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('default receipts is empty list', () {
      const data = MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 0);

      expect(data.receipts, isEmpty);
    });
  });

  group('SalesState', () {
    test('equality with same fields', () {
      const a = SalesState(status: SalesStatus.ready);
      const b = SalesState(status: SalesStatus.ready);

      expect(a, equals(b));
    });

    test('inequality with different months list', () {
      const a = SalesState();
      const b = SalesState(
        months: [MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 0)],
      );

      expect(a, isNot(equals(b)));
    });

    test('default months is empty list', () {
      const state = SalesState();

      expect(state.months, isEmpty);
    });

    test('copyWith clearMonths clears months list', () {
      const state = SalesState(
        months: [MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 0)],
      );
      final cleared = state.copyWith(clearMonths: true);

      expect(cleared.months, isEmpty);
    });

    test('copyWith preserves months when not cleared', () {
      const monthData = MonthData(year: 2026, month: 1, totalPiastres: 0, receiptCount: 0);
      const state = SalesState(months: [monthData]);
      final copied = state.copyWith();

      expect(copied.months, contains(monthData));
    });

    test('hashCode consistent with equality', () {
      const a = SalesState(status: SalesStatus.ready);
      const b = SalesState(status: SalesStatus.ready);

      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
