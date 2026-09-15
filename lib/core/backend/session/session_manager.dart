// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Session Management with Conflict Resolution
///
/// Implements the Two-Layer Model:
/// Layer 1: Firebase Auth (tenant_id = Firebase UID)
/// Layer 2: Real-time DB session tracking by username within tenant

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';

/// Represents a user session on a device
class UserSession {
  final String deviceId;
  final String deviceType; // 'pos' | 'web'
  final int loginTimestamp;
  int lastHeartbeat;
  SessionStatus status;
  final bool isPrimary;

  UserSession({
    required this.deviceId,
    required this.deviceType,
    required this.loginTimestamp,
    required this.lastHeartbeat,
    this.status = SessionStatus.active,
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() => {
    'device_id': deviceId,
    'device_type': deviceType,
    'login_timestamp': loginTimestamp,
    'last_heartbeat': lastHeartbeat,
    'status': status.name,
    'is_primary': isPrimary,
  };

  factory UserSession.fromMap(Map<dynamic, dynamic> map) {
    return UserSession(
      deviceId: map['device_id'] as String,
      deviceType: map['device_type'] as String,
      loginTimestamp: map['login_timestamp'] as int,
      lastHeartbeat: map['last_heartbeat'] as int,
      status: SessionStatus.values.byName(map['status'] as String),
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }

  UserSession copyWith({
    String? deviceId,
    String? deviceType,
    int? loginTimestamp,
    int? lastHeartbeat,
    SessionStatus? status,
    bool? isPrimary,
  }) {
    return UserSession(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      loginTimestamp: loginTimestamp ?? this.loginTimestamp,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      status: status ?? this.status,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

enum SessionStatus { active, offline, conflict, revoked }

/// Conflict state for a username
class SessionConflict {
  final String username;
  final String conflictCreatedAt;
  final String? conflictWinner;
  final ConflictState state;

  const SessionConflict({
    required this.username,
    required this.conflictCreatedAt,
    this.conflictWinner,
    required this.state,
  });

  Map<String, dynamic> toMap() => {
    'username': username,
    'conflict_created_at': conflictCreatedAt,
    'conflict_winner': conflictWinner,
    'state': state.name,
  };

  factory SessionConflict.fromMap(Map<dynamic, dynamic> map) {
    return SessionConflict(
      username: map['username'] as String,
      conflictCreatedAt: map['conflict_created_at'] as String,
      conflictWinner: map['conflict_winner'] as String?,
      state: ConflictState.values.byName(map['state'] as String),
    );
  }
}

enum ConflictState { none, pending, resolved }

/// Manages user sessions with conflict detection and resolution
class SessionManager {
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _conflictTimeout = Duration(seconds: 30);
  static const Duration _saveTimeout = Duration(seconds: 30);

  final DatabaseReference _sessionsRef;
  final FirebaseAuthService _authService;
  final String _tenantId;

  // In-memory cache of current user's sessions
  final Map<String, UserSession> _localSessions = {};
  StreamSubscription<DatabaseEvent>? _sessionsSubscription;
  String? _currentUsername;
  Timer? _heartbeatTimer;
  Timer? _conflictTimer;

  SessionManager({
    required DatabaseReference sessionsRef,
    required FirebaseAuthService authService,
    required String tenantId,
  }) : _sessionsRef = sessionsRef,
       _authService = authService,
       _tenantId = tenantId;

  /// Initialize session tracking for a username
  Future<Either<Failure, void>> initializeSession({
    required String username,
    required String deviceId,
    required String deviceType, // 'pos' | 'web'
    required bool isPrimary,
  }) async {
    _currentUsername = username;
    _localSessions.clear();

    // Set up real-time listener for this user's sessions
    final userSessionsRef = _sessionsRef.child('user_sessions/$username');
    _sessionsSubscription = userSessionsRef.onValue.listen(_onSessionsUpdate);

    // Create local session
    final session = UserSession(
      deviceId: deviceId,
      deviceType: deviceType,
      loginTimestamp: DateTime.now().millisecondsSinceEpoch,
      lastHeartbeat: DateTime.now().millisecondsSinceEpoch,
      status: SessionStatus.active,
      isPrimary: isPrimary,
    );

    _localSessions[deviceId] = session;

    // Write to real-time DB
    await _writeSession(username, deviceId, session);

    // Start heartbeat
    _startHeartbeat(username, deviceId);

    return Right(null);
  }

  /// Handle real-time updates from Firebase
  void _onSessionsUpdate(DatabaseEvent event) {
    if (event.snapshot.value == null) return;

    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    final sessions = data['sessions'] as Map?;
    if (sessions == null) return;

    // Check for conflicts
    final activeSessions = sessions.entries
        .where((e) => (e.value['status'] as String) == 'active')
        .toList();

    if (activeSessions.length > 1) {
      _handleConflict();
    }
  }

  /// Handle session conflict
  Future<void> _handleConflict() async {
    if (_currentUsername == null) return;

    final userSessionsRef = _sessionsRef.child(
      'user_sessions/$_currentUsername',
    );
    final conflictRef = userSessionsRef.child('conflict');

    // Mark conflict state
    await conflictRef.set({
      'state': 'pending',
      'conflict_created_at': DateTime.now().millisecondsSinceEpoch,
      'conflict_winner': null,
    });

    // Start conflict timer
    _conflictTimer?.cancel();
    _conflictTimer = Timer(Duration(seconds: 30), () => _autoResolveConflict());

    // Notify all sessions of conflict
    final sessionsSnapshot = await userSessionsRef.child('sessions').get();
    if (sessionsSnapshot.exists) {
      final sessions = Map<String, dynamic>.from(sessionsSnapshot.value as Map);
      for (final entry in sessions.entries) {
        final deviceId = entry.key;
        if (deviceId != _getCurrentDeviceId()) {
          await userSessionsRef.child('sessions/$deviceId').update({
            'status': 'conflict',
          });
        }
      }
    }

    // Hold second login (show loading screen)
    // This is handled by the UI layer
  }

  /// Auto-resolve conflict after timeout
  Future<void> _autoResolveConflict() async {
    if (_currentUsername == null) return;

    final userSessionsRef = _sessionsRef.child(
      'user_sessions/$_currentUsername',
    );
    final sessionsSnapshot = await userSessionsRef.child('sessions').get();

    if (!sessionsSnapshot.exists) return;

    final sessions = Map<String, dynamic>.from(sessionsSnapshot.value as Map);
    final activeSessions = sessions.entries
        .where(
          (e) =>
              (e.value['status'] as String) == 'active' ||
              (e.value['status'] as String) == 'conflict',
        )
        .toList();

    // Apply priority rules
    String? winnerDeviceId;
    if (activeSessions.length >= 2) {
      // Priority: POS > Web, Primary device > non-primary, Newer login
      final sorted = activeSessions
        ..sort((a, b) {
          final aIsPos = a.value['device_type'] == 'pos';
          final bIsPos = b.value['device_type'] == 'pos';
          if (aIsPos != bIsPos) return aIsPos ? -1 : 1;
          final aIsPrimary = a.value['is_primary'] == true;
          final bIsPrimary = b.value['is_primary'] == true;
          if (aIsPrimary != bIsPrimary) return aIsPrimary ? -1 : 1;
          return (a.value['login_timestamp'] as int).compareTo(
            b.value['login_timestamp'] as int,
          );
        });
      winnerDeviceId = sorted.first.key;
    }

    // Revoke all other sessions
    for (final entry in sessions.entries) {
      if (entry.key != winnerDeviceId) {
        await userSessionsRef.child('sessions/${entry.key}').update({
          'status': 'revoked',
        });
      }
    }

    // Clear conflict state
    await _sessionsRef.child('user_sessions/$_currentUsername/conflict').set({
      'state': 'resolved',
      'conflict_winner': winnerDeviceId,
      'resolved_at': DateTime.now().millisecondsSinceEpoch,
    });

    _conflictTimer?.cancel();
  }

  /// Heartbeat to keep session alive
  void _startHeartbeat(String username, String deviceId) {
    // Heartbeat implementation
  }

  Future<void> _writeSession(
    String username,
    String deviceId,
    UserSession session,
  ) async {
    await _sessionsRef
        .child('user_sessions/$username/sessions/$deviceId')
        .set(session.toMap());
  }

  String? _getCurrentDeviceId() {
    return _authService.currentUserUid;
  }

  /// End session gracefully
  Future<void> endSession(String username, String deviceId) async {
    _heartbeatTimer?.cancel();
    _conflictTimer?.cancel();
    _sessionsSubscription?.cancel();

    final session = _localSessions[deviceId];
    if (session != null) {
      await _sessionsRef
          .child('user_sessions/$username/sessions/$deviceId')
          .update({'status': 'revoked'});
      _localSessions.remove(deviceId);
    }
    _sessionsSubscription?.cancel();
  }

  /// Get current session state for a username
  Future<Map<String, dynamic>> getSessionState(String username) async {
    final snapshot = await _sessionsRef.child('user_sessions/$username').get();
    if (!snapshot.exists) return {};
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Revoke a specific session (for admin use)
  Future<void> revokeSession(
    String username,
    String deviceId,
    String reason,
  ) async {
    await _sessionsRef
        .child('user_sessions/$username/sessions/$deviceId')
        .update({'status': 'revoked', 'revoked_reason': reason});
  }
}
