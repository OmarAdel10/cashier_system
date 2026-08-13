import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';

void main() {
  group('TableEntity', () {
    test('should default to available with capacity 1', () {
      const table = TableEntity(id: 't1', name: 'T1');

      expect(table.status, TableStatus.available);
      expect(table.capacity, 1);
      expect(table.isRoom, false);
      expect(table.hourlyRatePiastres, 0);
      expect(table.isRoomEnabled, false);
      expect(table.tabOpenedAt, isNull);
      expect(table.activeRoundNumber, isNull);
    });

    test('should expose isRoom through isRoomEnabled passthrough', () {
      const table = TableEntity(
        id: 't1',
        name: 'T1',
        isRoom: true,
        hourlyRatePiastres: 5000,
      );

      expect(table.isRoomEnabled, true);
    });

    test('copyWith should keep tabOpenedAt when not provided', () {
      final opened = DateTime(2026, 8, 9, 10, 0);
      final table = TableEntity(
        id: 't1',
        name: 'T1',
        status: TableStatus.occupied,
        tabOpenedAt: opened,
      );

      final copy = table.copyWith(name: 'T2');

      expect(copy.tabOpenedAt, opened);
      expect(copy.activeRoundNumber, isNull);
    });

    test('copyWith should clear tabOpenedAt when null is explicit', () {
      final opened = DateTime(2026, 8, 9, 10, 0);
      final table = TableEntity(
        id: 't1',
        name: 'T1',
        tabOpenedAt: opened,
        activeRoundNumber: 2,
      );

      final copy = table.copyWith(tabOpenedAt: null, activeRoundNumber: null);

      expect(copy.tabOpenedAt, isNull);
      expect(copy.activeRoundNumber, isNull);
    });

    test('copyWith should update status and activeRoundNumber', () {
      const table = TableEntity(id: 't1', name: 'T1');

      final copy = table.copyWith(
        status: TableStatus.orderPending,
        activeRoundNumber: 1,
      );

      expect(copy.status, TableStatus.orderPending);
      expect(copy.activeRoundNumber, 1);
    });

    test('chargedHours should be at least 1', () {
      final table = TableEntity(id: 't1', name: 'T1', isRoom: true);

      expect(table.chargedHours, 1);
    });

    test('chargedHours should ceil elapsed minutes to hours', () {
      final table = TableEntity(
        id: 't1',
        name: 'T1',
        isRoom: true,
        tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 90)),
      );

      expect(table.chargedHours, 2);
    });

    test('roomChargePiastres should multiply charged hours by rate', () {
      final table = TableEntity(
        id: 't1',
        name: 'T1',
        isRoom: true,
        hourlyRatePiastres: 5000,
        tabOpenedAt: DateTime.now().subtract(const Duration(minutes: 130)),
      );

      expect(table.chargedHours, 3);
      expect(table.roomChargePiastres, 15000);
    });

    test('should respect equality', () {
      const a = TableEntity(id: 't1', name: 'T1', capacity: 4, zoneId: 'z1');
      const b = TableEntity(id: 't1', name: 'T1', capacity: 4, zoneId: 'z1');
      const c = TableEntity(id: 't2', name: 'T1', capacity: 4, zoneId: 'z1');

      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}
