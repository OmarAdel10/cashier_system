// Copyright (c) 2026 Daftari POS. All rights reserved.

library;

/// Dashboard data models + mappers from the api worker's JSON shapes
/// (admin-dashboard T12).

/// Reads a required string field from an untrusted API object. A missing or
/// wrongly-typed field is a *data* failure, so it is classified as a
/// [FormatException] (an `Exception`) — the loaders handle that and show an
/// error instead of leaking a `TypeError` (a programming Error that must
/// never be swallowed) into a forever-loading screen.
String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty String');
  }
  return value;
}

/// Tolerant numeric coercion: anything that is not a number is 0.
int _asInt(Object? value) => value is num ? value.toInt() : 0;

/// The four quick-stat cards (spec §2.5.2: Sales, Revenue, Devices Online,
/// Alerts — the spec's Items card waits for an api field; Phase 2).
class OverviewStats {
  final int saleCount;
  final int totalPiastres;
  final int activeSessions;
  final int devicesOnline;
  final int alerts;

  const OverviewStats({
    required this.saleCount,
    required this.totalPiastres,
    required this.activeSessions,
    required this.devicesOnline,
    required this.alerts,
  });
}

class DeviceCardModel {
  final String deviceHwid;
  final String? deviceName;
  final String? platform;
  final int lastSeenAt;

  /// Present = a live POS session on this device.
  final String? activeUsername;
  final int? sessionStartedAt;

  /// A device is online when it has an active session OR a fresh heartbeat.
  bool isOnline(int nowMs) {
    if (activeUsername != null) return true;
    return nowMs - lastSeenAt < 5 * 60 * 1000;
  }

  const DeviceCardModel({
    required this.deviceHwid,
    required this.lastSeenAt,
    this.deviceName,
    this.platform,
    this.activeUsername,
    this.sessionStartedAt,
  });

  factory DeviceCardModel.fromJson(Map<String, dynamic> json) {
    final session = json['active_session'];
    final sessionJson = session is Map<String, dynamic> ? session : null;
    return DeviceCardModel(
      deviceHwid: _requireString(json, 'device_hwid'),
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      lastSeenAt: _asInt(json['last_seen_at']),
      activeUsername: sessionJson?['username'] as String?,
      sessionStartedAt: sessionJson == null
          ? null
          : _asInt(sessionJson['started_at']),
    );
  }
}

class ActivityEventModel {
  final String type;
  final int at;
  final String summary;

  const ActivityEventModel({
    required this.type,
    required this.at,
    required this.summary,
  });

  factory ActivityEventModel.fromJson(Map<String, dynamic> json) =>
      ActivityEventModel(
        type: _requireString(json, 'type'),
        at: _asInt(json['at']),
        summary: json['summary'] as String? ?? '',
      );
}

/// An active POS session (the Active Shifts panel, view-only).
class SessionCardModel {
  final String id;
  final String username;
  final String deviceHwid;
  final int startedAt;
  final int heartbeatAt;

  const SessionCardModel({
    required this.id,
    required this.username,
    required this.deviceHwid,
    required this.startedAt,
    required this.heartbeatAt,
  });

  factory SessionCardModel.fromJson(Map<String, dynamic> json) =>
      SessionCardModel(
        id: _requireString(json, 'id'),
        username: json['username'] as String? ?? '',
        deviceHwid: json['device_hwid'] as String? ?? '',
        startedAt: _asInt(json['started_at']),
        heartbeatAt: _asInt(json['heartbeat_at']),
      );
}

/// Pure mapper for the /admin/overview + /admin/devices payloads.
OverviewStats mapOverview(
  Map<String, dynamic> overviewBody,
  List<Map<String, dynamic>> deviceJsons,
  int nowMs,
) {
  final rawData = overviewBody['data'];
  final data = rawData is Map<String, dynamic> ? rawData : const {};
  final rawStats = data['stats'];
  final stats = rawStats is Map<String, dynamic> ? rawStats : const {};
  final devices = deviceJsons.map(DeviceCardModel.fromJson).toList();
  final online = devices.where((d) => d.isOnline(nowMs)).length;
  return OverviewStats(
    saleCount: _asInt(stats['saleCount']),
    totalPiastres: _asInt(stats['totalPiastres']),
    activeSessions: _asInt(data['active_sessions']),
    devicesOnline: online,
    alerts: devices.length - online,
  );
}
