// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Session sync service for device-level session tracking.
///
/// Wraps SyncService from the Cloudflare Workers REST API surface at
/// daftari-api/sessions/*. Only used by [cloud] / [admin] flavors —
/// local flavor never syncs sessions.
library;

import 'dart:async';

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'api_client.dart';

/// Manages per-device session registration on daftari-api. Each start call
/// extracts the device HWID + device name, registers it, then heartbeats
/// periodically. Device-tracking lives server-side (limits enforced at
/// /sessions/start).
class SessionSyncService {
  SessionSyncService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// POST /sessions/start: begin tracking this device, checking the
  /// per-tenant device limit. Returns the session ID when successful;
  /// LEFT Failure on 409 (device-limit reached).
  Future<Either<Failure, Map<String, dynamic>>> startSession({
    required String deviceHwid,
    String? deviceName,
    String? platform,
    String? username,
    required String idToken,
  }) {
    return _api.post('/sessions/start', {
      'device_hwid': deviceHwid,
      'device_name': ?deviceName,
      'platform': ?platform,
      'username': ?username,
    }, idToken: idToken);
  }

  /// POST /sessions/heartbeat — periodic keep-alive for the session timer.
  Future<Either<Failure, Map<String, dynamic>>> heartbeat({
    required String sessionId,
    required String idToken,
  }) {
    return _api.post('/sessions/heartbeat', {
      'session_id': sessionId,
    }, idToken: idToken);
  }

  /// POST /sessions/end — cleanly close the session on logout/shift end.
  Future<Either<Failure, Map<String, dynamic>>> endSession({
    required String sessionId,
    required String idToken,
  }) {
    return _api.post('/sessions/end', {
      'session_id': sessionId,
    }, idToken: idToken);
  }

  /// GET /sessions/active — list currently active sessions for the tenant.
  Future<Either<Failure, Map<String, dynamic>>> activeSessions({
    required String idToken,
  }) {
    return _api.get('/sessions/active', idToken: idToken);
  }
}
