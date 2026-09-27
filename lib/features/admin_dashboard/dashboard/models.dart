// Copyright (c) 2026 Daftari POS. All rights reserved.

library;

/// Dashboard data models + mappers from the api worker's JSON shapes
/// (admin-dashboard T12).

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
    final session = json['active_session'] as Map<String, dynamic>?;
    return DeviceCardModel(
      deviceHwid: json['device_hwid']! as String,
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      lastSeenAt: (json['last_seen_at'] as num?)?.toInt() ?? 0,
      activeUsername: session?['username'] as String?,
      sessionStartedAt: (session?['started_at'] as num?)?.toInt(),
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
        type: json['type']! as String,
        at: (json['at'] as num?)?.toInt() ?? 0,
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
        id: json['id']! as String,
        username: json['username'] as String? ?? '',
        deviceHwid: json['device_hwid'] as String? ?? '',
        startedAt: (json['started_at'] as num?)?.toInt() ?? 0,
        heartbeatAt: (json['heartbeat_at'] as num?)?.toInt() ?? 0,
      );
}

/// Pure mapper for the /admin/overview + /admin/devices payloads.
OverviewStats mapOverview(
  Map<String, dynamic> overviewBody,
  List<Map<String, dynamic>> deviceJsons,
  int nowMs,
) {
  final data = overviewBody['data'] as Map<String, dynamic>? ?? const {};
  final stats = data['stats'] as Map<String, dynamic>? ?? const {};
  final devices = deviceJsons.map(DeviceCardModel.fromJson).toList();
  final online = devices.where((d) => d.isOnline(nowMs)).length;
  return OverviewStats(
    saleCount: (stats['saleCount'] as num?)?.toInt() ?? 0,
    totalPiastres: (stats['totalPiastres'] as num?)?.toInt() ?? 0,
    activeSessions: (data['active_sessions'] as num?)?.toInt() ?? 0,
    devicesOnline: online,
    alerts: devices.length - online,
  );
}
