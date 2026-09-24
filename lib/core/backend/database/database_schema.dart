// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:cashier_system/core/error/failure.dart';

/// Local database schema: Hive box names, device maps, rooms, audit log.
///
/// Builds on Task 3 RealTimeDb (`tenants/{tenantId}/sessions/...`) without
/// altering session-tracking behavior. This file is pure-Dart so it stays
/// unit-testable without Hive initialization.
///
/// Box inventory matches spec §5j (Hive Box Summary): 16 boxes. Regular
/// [Box]es hold typed models; [lazyBoxNames] hold large/append-only payloads
/// (receipts, refunds, audit JSON strings, expenses).
class DatabaseSchema {
  /// Schema version for future migrations.
  static const int version = 1;

  /// Audit log retention window in days.
  static const int auditRetentionDays = 90;

  /// Hive box name for the audit log.
  static const String auditLogBox = 'audit_log';

  /// All 16 Hive box names used by the app (spec §5j).
  static const List<String> boxNames = <String>[
    'auth_users',
    'shifts',
    'active_shifts',
    'settings',
    'inventory',
    'receipts',
    'refunds',
    auditLogBox,
    'product_categories',
    'stations',
    'session_records',
    'floor_zones',
    'tables',
    'table_rounds',
    'table_order_lines',
    'expenses',
  ];

  /// Boxes opened as Hive LazyBox (large or append-only payloads).
  static const Set<String> lazyBoxNames = <String>{
    'receipts',
    'refunds',
    auditLogBox,
    'expenses',
  };

  /// True when [name] must be opened as a LazyBox.
  static bool isLazyBox(String name) => lazyBoxNames.contains(name);

  /// Device id -> zone id.
  static final Map<String, String> _deviceZoneMap = <String, String>{};

  /// Device id -> floor id.
  static final Map<String, String> _deviceFloorMap = <String, String>{};

  /// Device id -> printer ids.
  static final Map<String, List<String>> _devicePrinters =
      <String, List<String>>{};

  /// Rooms table: room id -> [Room].
  static final Map<String, Room> _rooms = <String, Room>{};

  /// In-memory audit log buffer (persisted to [auditLogBox]).
  static final List<AuditLogEntry> _auditLog = <AuditLogEntry>[];

  /// Unmodifiable view of device -> zone assignments.
  static Map<String, String> get deviceZoneMap =>
      UnmodifiableMapView(_deviceZoneMap);

  /// Unmodifiable view of device -> floor assignments.
  static Map<String, String> get deviceFloorMap =>
      UnmodifiableMapView(_deviceFloorMap);

  /// Unmodifiable view of device -> printer ids.
  static Map<String, List<String>> get devicePrinters =>
      UnmodifiableMapView(_devicePrinters);

  /// Unmodifiable view of rooms table.
  static Map<String, Room> get rooms => UnmodifiableMapView(_rooms);

  /// Unmodifiable view of the in-memory audit buffer.
  static List<AuditLogEntry> get auditLog => UnmodifiableListView(_auditLog);

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$field cannot be empty');
    }
  }

  /// Assigns a zone to a device.
  static void assignDeviceZone(String deviceId, String zoneId) {
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(zoneId, 'zoneId');
    _deviceZoneMap[deviceId] = zoneId;
  }

  /// Assigns a floor to a device.
  static void assignDeviceFloor(String deviceId, String floorId) {
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(floorId, 'floorId');
    _deviceFloorMap[deviceId] = floorId;
  }

  /// Sets the printers reachable from a device (defensive copy).
  static void setDevicePrinters(String deviceId, List<String> printerIds) {
    _requireNonEmpty(deviceId, 'deviceId');
    _devicePrinters[deviceId] = List<String>.unmodifiable(printerIds);
  }

  /// Adds or replaces a room.
  static void addRoom(Room room) {
    _requireNonEmpty(room.id, 'room.id');
    _requireNonEmpty(room.name, 'room.name');
    _requireNonEmpty(room.zoneId, 'room.zoneId');
    _requireNonEmpty(room.floorId, 'room.floorId');
    _rooms[room.id] = room;
  }

  /// Returns the room for [id], or null when missing.
  static Room? getRoom(String id) => _rooms[id];

  /// Appends an audit entry.
  static void logAudit(AuditLogEntry entry) {
    _requireNonEmpty(entry.action, 'audit.action');
    _requireNonEmpty(entry.user, 'audit.user');
    _auditLog.add(entry);
  }

  /// Removes entries older than [auditRetentionDays].
  ///
  /// Returns the number of purged entries.
  static int purgeExpiredAuditLog({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final before = _auditLog.length;
    _auditLog.removeWhere((e) => e.isExpired(now: ref));
    return before - _auditLog.length;
  }

  /// Resets mutable static state (tests only; never call in prod).
  @visibleForTesting
  static void clearAllForTests() {
    _deviceZoneMap.clear();
    _deviceFloorMap.clear();
    _devicePrinters.clear();
    _rooms.clear();
    _auditLog.clear();
  }
}

/// A dining/service room linked to a zone and a floor.
class Room {
  final String id;
  final String name;
  final String zoneId;
  final String floorId;

  const Room({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.floorId,
  });

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'zoneId': zoneId, 'floorId': floorId};
  }

  static String _readString(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) {
      throw DatabaseFailure('Room: missing required key "$key"');
    }
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw DatabaseFailure(
        'Room: invalid type for "$key" (expected non-empty String)',
      );
    }
    return value;
  }

  factory Room.fromMap(Map<dynamic, dynamic> map) {
    return Room(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      zoneId: _readString(map, 'zoneId'),
      floorId: _readString(map, 'floorId'),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Room &&
        other.id == id &&
        other.name == name &&
        other.zoneId == zoneId &&
        other.floorId == floorId;
  }

  @override
  int get hashCode => Object.hash(id, name, zoneId, floorId);

  @override
  String toString() =>
      'Room(id: $id, name: $name, zoneId: $zoneId, floorId: $floorId)';
}

/// Immutable audit log entry with 90-day retention.
class AuditLogEntry {
  final String action;
  final DateTime timestamp;
  final String user;

  const AuditLogEntry({
    required this.action,
    required this.timestamp,
    required this.user,
  });

  /// True when older than [DatabaseSchema.auditRetentionDays] from [now].
  ///
  /// Boundary: an entry exactly [DatabaseSchema.auditRetentionDays] old is
  /// NOT expired; only a strictly greater [Duration] counts as expired.
  bool isExpired({DateTime? now}) {
    final ref = now ?? DateTime.now();
    return ref.difference(timestamp) >
        Duration(days: DatabaseSchema.auditRetentionDays);
  }

  Map<String, Object?> toMap() {
    return {
      'action': action,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'user': user,
    };
  }

  static String _readString(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) {
      throw DatabaseFailure('AuditLogEntry: missing required key "$key"');
    }
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw DatabaseFailure(
        'AuditLogEntry: invalid type for "$key" '
        '(expected non-empty String)',
      );
    }
    return value;
  }

  /// Max millis accepted (year 9999); larger values throw in DateTime.
  static const int _maxTimestampMillis = 253402300799999;

  static int _readTimestampMillis(Map<dynamic, dynamic> map) {
    if (!map.containsKey('timestamp')) {
      throw DatabaseFailure('AuditLogEntry: missing required key "timestamp"');
    }
    final value = map['timestamp'];
    // Accept int or double (JSON numbers may decode as double).
    int millis;
    if (value is int) {
      millis = value;
    } else if (value is double) {
      if (!value.isFinite) {
        throw DatabaseFailure('AuditLogEntry: invalid timestamp value $value');
      }
      millis = value.toInt();
    } else {
      throw DatabaseFailure(
        'AuditLogEntry: invalid type for "timestamp" (expected num)',
      );
    }
    if (millis <= 0 || millis > _maxTimestampMillis) {
      throw DatabaseFailure('AuditLogEntry: invalid timestamp value $value');
    }
    return millis;
  }

  factory AuditLogEntry.fromMap(Map<dynamic, dynamic> map) {
    return AuditLogEntry(
      action: _readString(map, 'action'),
      timestamp: DateTime.fromMillisecondsSinceEpoch(_readTimestampMillis(map)),
      user: _readString(map, 'user'),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuditLogEntry &&
        other.action == action &&
        other.timestamp == timestamp &&
        other.user == user;
  }

  @override
  int get hashCode => Object.hash(action, timestamp, user);

  @override
  String toString() =>
      'AuditLogEntry(action: $action, timestamp: $timestamp, user: ***)';
}

/// Convergence bridge between the in-memory [DatabaseSchema] audit buffer
/// and the persisted audit trail.
///
/// DO NOT rewire stores here: the source of truth for persisted audit data
/// is `AuditService` over the encrypted `LazyBox<String>('audit_log')`,
/// where entries are JSON strings (see `lib/core/audit/audit_service.dart`).
/// This adapter only converts between the in-memory [AuditLogEntry] buffer
/// and that JSON-string form so a future migration can drain/replay the
/// buffer without touching any repository or bloc. No store wiring changes.
class AuditLogConvergenceBridge {
  const AuditLogConvergenceBridge._();

  /// Serializes the in-memory buffer to JSON-compatible maps (one per entry).
  static List<Map<String, Object?>> exportBuffer() =>
      DatabaseSchema.auditLog.map((e) => e.toMap()).toList();

  /// Replays persisted maps back into the in-memory buffer.
  ///
  /// Invalid or expired entries are skipped so one corrupt row cannot fail
  /// convergence and the 90-day retention holds on replay. Returns the
  /// number of entries replayed.
  static int importBuffer(Iterable<Map> persisted, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    var count = 0;
    for (final map in persisted) {
      try {
        final entry = AuditLogEntry.fromMap(map);
        if (entry.isExpired(now: ref)) continue;
        DatabaseSchema.logAudit(entry);
        count++;
      } catch (_) {
        continue;
      }
    }
    return count;
  }
}
