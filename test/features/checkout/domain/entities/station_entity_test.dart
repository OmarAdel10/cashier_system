import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';

void main() {
  group('StationEntity', () {
    const station = StationEntity(
      id: 'PS4-1',
      name: 'PS4-1',
      parentCategory: 'PS4',
      stationType: StationType.playstation,
      normalHourlyRate: 50.0,
      multiHourlyRate: 75.0,
      minimumGameCostNormal: 100,
      minimumGameCostMulti: 150,
      iconAsset: 'assets/icons/ps4.svg',
      status: StationStatus.available,
    );

    test('creates with all fields', () {
      expect(station.id, 'PS4-1');
      expect(station.normalHourlyRate, 50.0);
      expect(station.multiHourlyRate, 75.0);
      expect(station.minimumGameCostNormal, 100);
      expect(station.minimumGameCostMulti, 150);
      expect(station.status, StationStatus.available);
    });

    test('copyWith updates single field', () {
      final updated = station.copyWith(status: StationStatus.active);
      expect(updated.status, StationStatus.active);
      expect(updated.id, station.id);
    });

    test('equality and hashCode', () {
      const other = StationEntity(
        id: 'PS4-1',
        name: 'PS4-1',
        parentCategory: 'PS4',
        stationType: StationType.playstation,
        normalHourlyRate: 50.0,
        multiHourlyRate: 75.0,
        minimumGameCostNormal: 100,
        minimumGameCostMulti: 150,
        iconAsset: 'assets/icons/ps4.svg',
        status: StationStatus.available,
      );
      expect(station == other, true);
      expect(station.hashCode == other.hashCode, true);
    });

    test('copyWith clears session fields when passed null', () {
      final started = station.copyWith(
        status: StationStatus.active,
        sessionStartTime: DateTime(2026, 1, 1),
        isFixedDuration: true,
        fixedDurationMinutes: 120,
        overtimeStartMinutes: 60,
      );
      expect(started.sessionStartTime, isNotNull);
      expect(started.fixedDurationMinutes, 120);

      final cleared = started.copyWith(
        status: StationStatus.available,
        sessionStartTime: null,
        isFixedDuration: false,
        fixedDurationMinutes: null,
        overtimeStartMinutes: null,
      );
      expect(cleared.sessionStartTime, isNull);
      expect(cleared.fixedDurationMinutes, isNull);
      expect(cleared.overtimeStartMinutes, isNull);
      expect(cleared.isFixedDuration, false);
    });

    test('elapsedMinutes is 0 without session start', () {
      expect(station.elapsedMinutes, 0);
    });

    test('currentTotalPiastres is 0 when available', () {
      expect(station.currentTotalPiastres, 0);
    });
  });
}
