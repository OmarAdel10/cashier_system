import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

void main() {
  group('SessionRecordEntity', () {
    const record = SessionRecordEntity(
      id: 'SR-1',
      shiftId: 'SHIFT-1',
      stationId: 'PS4-1',
      stationName: 'PS4-1',
      parentCategory: 'PS4',
      tier: SessionTier.normal,
      startTime: null,
      endTime: null,
      durationMinutes: 60,
      hourlyRate: 50.0,
      minimumGameCost: 100,
      subtotalPiastres: 5000,
      totalPiastres: 5000,
    );

    test('creates with all fields', () {
      expect(record.id, 'SR-1');
      expect(record.stationId, 'PS4-1');
      expect(record.tier, SessionTier.normal);
      expect(record.durationMinutes, 60);
      expect(record.subtotalPiastres, 5000);
      expect(record.totalPiastres, 5000);
      expect(record.status, SessionRecordStatus.completed);
    });

    test('copyWith updates single field', () {
      final updated = record.copyWith(totalPiastres: 5500);
      expect(updated.totalPiastres, 5500);
      expect(updated.id, record.id);
    });

    test('equality and hashCode', () {
      const other = SessionRecordEntity(
        id: 'SR-1',
        shiftId: 'SHIFT-1',
        stationId: 'PS4-1',
        stationName: 'PS4-1',
        parentCategory: 'PS4',
        tier: SessionTier.normal,
        startTime: null,
        endTime: null,
        durationMinutes: 60,
        wasFixedDuration: false,
        fixedDurationMinutes: null,
        hourlyRate: 50.0,
        minimumGameCost: 100,
        subtotalPiastres: 5000,
        discountPiastres: 0,
        taxPiastres: 0,
        totalPiastres: 5000,
        taxPercent: 0,
        discountPercent: 0,
        username: '',
        paymentType: 'cash',
        amountPaidPiastres: null,
        status: SessionRecordStatus.completed,
      );
      expect(record == other, true);
      expect(record.hashCode == other.hashCode, true);
    });
  });
}
