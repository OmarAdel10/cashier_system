import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/backend/database/database_schema.dart';

void main() {
  setUp(() {
    DatabaseSchema.clearAllForTests();
  });

  group('DatabaseSchema boxes', () {
    test('schema exposes exactly 19 Hive boxes', () {
      expect(DatabaseSchema.boxNames, hasLength(19));
    });

    test('box names are unique and non-empty', () {
      final names = DatabaseSchema.boxNames;
      expect(names.toSet(), hasLength(names.length));
      for (final name in names) {
        expect(name.isNotEmpty, isTrue, reason: 'empty box name');
      }
    });

    test('schema contains required core boxes', () {
      for (final required in [
        'auth_users',
        'active_shifts',
        'shifts',
        'products',
        'inventory',
        'receipts',
        'rooms',
        'audit_log',
      ]) {
        expect(DatabaseSchema.boxNames, contains(required));
      }
    });

    test('audit log box constant matches schema', () {
      expect(DatabaseSchema.auditLogBox, equals('audit_log'));
      expect(DatabaseSchema.boxNames, contains(DatabaseSchema.auditLogBox));
    });
  });

  group('device maps', () {
    test('deviceZoneMap assigns and reads zone', () {
      DatabaseSchema.assignDeviceZone('device-1', 'zone-a');
      expect(DatabaseSchema.deviceZoneMap['device-1'], equals('zone-a'));
    });

    test('deviceFloorMap assigns and reads floor', () {
      DatabaseSchema.assignDeviceFloor('device-1', 'floor-1');
      expect(DatabaseSchema.deviceFloorMap['device-1'], equals('floor-1'));
    });

    test('devicePrinters assigns and reads printers', () {
      DatabaseSchema.setDevicePrinters('device-1', ['printer-1', 'printer-2']);
      expect(
        DatabaseSchema.devicePrinters['device-1'],
        equals(['printer-1', 'printer-2']),
      );
    });
  });

  group('rooms table', () {
    test('addRoom and getRoom roundtrip', () {
      const room = Room(
        id: 'room-1',
        name: 'VIP 1',
        zoneId: 'zone-a',
        floorId: 'floor-1',
      );
      DatabaseSchema.addRoom(room);
      expect(DatabaseSchema.getRoom('room-1'), equals(room));
      expect(DatabaseSchema.rooms, contains('room-1'));
    });

    test('rooms table holds multiple rooms', () {
      DatabaseSchema.addRoom(
        const Room(id: 'r1', name: 'A', zoneId: 'z1', floorId: 'f1'),
      );
      DatabaseSchema.addRoom(
        const Room(id: 'r2', name: 'B', zoneId: 'z1', floorId: 'f2'),
      );
      expect(DatabaseSchema.rooms, hasLength(2));
    });
  });

  group('audit log 90-day retention', () {
    test('AuditLogEntry holds action, timestamp, user', () {
      final now = DateTime.now();
      final entry = AuditLogEntry(
        action: 'sale.created',
        timestamp: now,
        user: 'omar',
      );
      expect(entry.action, equals('sale.created'));
      expect(entry.timestamp, equals(now));
      expect(entry.user, equals('omar'));
    });

    test('retention window is 90 days', () {
      expect(DatabaseSchema.auditRetentionDays, equals(90));
    });

    test('recent entries are retained, old entries purged', () {
      final now = DateTime.now();
      DatabaseSchema.logAudit(
        AuditLogEntry(
          action: 'recent',
          timestamp: now.subtract(const Duration(days: 10)),
          user: 'omar',
        ),
      );
      DatabaseSchema.logAudit(
        AuditLogEntry(
          action: 'old',
          timestamp: now.subtract(const Duration(days: 91)),
          user: 'omar',
        ),
      );
      expect(DatabaseSchema.auditLog, hasLength(2));
      final purged = DatabaseSchema.purgeExpiredAuditLog(now: now);
      expect(purged, equals(1));
      expect(DatabaseSchema.auditLog, hasLength(1));
      expect(DatabaseSchema.auditLog.first.action, equals('recent'));
    });

    test('entry exactly at boundary behavior is deterministic', () {
      final now = DateTime.now();
      final entry = AuditLogEntry(
        action: 'boundary',
        timestamp: now.subtract(const Duration(days: 90)),
        user: 'omar',
      );
      expect(entry.isExpired(now: now), isFalse);
      final expired = AuditLogEntry(
        action: 'expired',
        timestamp: now.subtract(const Duration(days: 91)),
        user: 'omar',
      );
      expect(expired.isExpired(now: now), isTrue);
    });

    test('AuditLogEntry toMap/fromMap roundtrip', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      const action = 'shift.closed';
      const user = 'cashier1';
      final original = AuditLogEntry(
        action: action,
        timestamp: now,
        user: user,
      );
      final restored = AuditLogEntry.fromMap(original.toMap());
      expect(restored, equals(original));
    });
  });
}
