// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Session sync service: tracks device sessions for a tenant via the
/// REST APIs on daftari-api worker (/sessions/*).
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'api_client.dart';

class SessionSyncService {
  SessionSyncService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// POST /sessions/start — begins tracking this device.
  /// Returns session_id (200) on first device, or 409 with active list if
  /// the device limit is exceeded (e.g. 2nd device on 'starter' tier).
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

  /// POST /sessions/heartbeat — keep-alive heartbeat (60s).
  Future<Either<Failure, Map<String, dynamic>>> heartbeat({
    required String sessionId,
    required String idToken,
  }) {
    return _api.post('/sessions/heartbeat', {
      'session_id': sessionId,
    }, idToken: idToken);
  }

  /// POST /sessions/end — gracefully close a session.
  Future<Either<Failure, Map<String, dynamic>>> endSession({
    required String sessionId,
    required String idToken,
  }) {
    return _api.post('/sessions/end', {
      'session_id': sessionId,
    }, idToken: idToken);
  }

  /// GET /sessions/active — list all open sessions for this tenant.
  Future<Either<Failure, Map<String, dynamic>>> activeSessions({
    required String idToken,
  }) {
    return _api.get('/sessions/active', idToken: idToken);
  }
}
