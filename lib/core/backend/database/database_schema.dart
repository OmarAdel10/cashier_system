// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Local database schema: Hive box names, device maps, rooms, audit log.
///
/// Builds on Task 3 RealTimeDb (`tenants/{tenantId}/sessions/...`) without
/// altering session-tracking behavior. This file is pure-Dart so it stays
/// unit-testable without Hive initialization.
class DatabaseSchema {
  /// Schema version for future migrations.
  static const int version = 1;

  /// Audit log retention window in days.
  static const int auditRetentionDays = 90;

  /// Hive box name for the audit log.
  static const String auditLogBox = 'audit_log';

  /// All 19 Hive box names used by the app.
  static const List<String> boxNames = <String>[
    'auth_users',
    'active_shifts',
    'shifts',
    'products',
    'inventory',
    'receipts',
    'customers',
    'suppliers',
    'settings',
    'tenants',
    'sessions_cache',
    'rooms',
    'zones',
    'floors',
    'devices',
    'printers',
    'payments',
    'discounts',
    'audit_log',
  ];

  /// Device id -> zone id.
  static final Map<String, String> deviceZoneMap = <String, String>{};

  /// Device id -> floor id.
  static final Map<String, String> deviceFloorMap = <String, String>{};

  /// Device id -> printer ids.
  static final Map<String, List<String>> devicePrinters =
      <String, List<String>>{};

  /// Rooms table: room id -> [Room].
  static final Map<String, Room> rooms = <String, Room>{};

  /// In-memory audit log buffer (persisted to [auditLogBox]).
  static final List<AuditLogEntry> auditLog = <AuditLogEntry>[];

  /// Assigns a zone to a device.
  static void assignDeviceZone(String deviceId, String zoneId) {
    deviceZoneMap[deviceId] = zoneId;
  }

  /// Assigns a floor to a device.
  static void assignDeviceFloor(String deviceId, String floorId) {
    deviceFloorMap[deviceId] = floorId;
  }

  /// Sets the printers reachable from a device.
  static void setDevicePrinters(String deviceId, List<String> printerIds) {
    devicePrinters[deviceId] = List<String>.unmodifiable(printerIds);
  }

  /// Adds or replaces a room.
  static void addRoom(Room room) {
    rooms[room.id] = room;
  }

  /// Returns the room for [id], or null when missing.
  static Room? getRoom(String id) => rooms[id];

  /// Appends an audit entry.
  static void logAudit(AuditLogEntry entry) {
    auditLog.add(entry);
  }

  /// Removes entries older than [auditRetentionDays].
  ///
  /// Returns the number of purged entries.
  static int purgeExpiredAuditLog({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final before = auditLog.length;
    auditLog.removeWhere((e) => e.isExpired(now: ref));
    return before - auditLog.length;
  }

  /// Resets mutable static state (tests only).
  static void clearAllForTests() {
    deviceZoneMap.clear();
    deviceFloorMap.clear();
    devicePrinters.clear();
    rooms.clear();
    auditLog.clear();
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

  factory Room.fromMap(Map<dynamic, dynamic> map) {
    return Room(
      id: map['id'] as String,
      name: map['name'] as String,
      zoneId: map['zoneId'] as String,
      floorId: map['floorId'] as String,
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
  bool isExpired({DateTime? now}) {
    final ref = now ?? DateTime.now();
    return ref.difference(timestamp).inDays > DatabaseSchema.auditRetentionDays;
  }

  Map<String, Object?> toMap() {
    return {
      'action': action,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'user': user,
    };
  }

  factory AuditLogEntry.fromMap(Map<dynamic, dynamic> map) {
    return AuditLogEntry(
      action: map['action'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      user: map['user'] as String,
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
      'AuditLogEntry(action: $action, timestamp: $timestamp, user: $user)';
}
