// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';

/// Session data stored in the real-time database.
class SessionData {
  final String username;
  final String tenantId;
  final String deviceId;
  final DateTime startedAt;
  final DateTime? lastActiveAt;
  final bool isActive;

  const SessionData({
    required this.username,
    required this.tenantId,
    required this.deviceId,
    required this.startedAt,
    this.lastActiveAt,
    required this.isActive,
  });

  Map<String, Object?> toMap() {
    return {
      'username': username,
      'tenantId': tenantId,
      'deviceId': deviceId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt?.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  static String _readString(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) {
      throw FormatException('Missing required key: $key');
    }
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Invalid type for key: $key (expected non-empty String)',
      );
    }
    return value;
  }

  static int _readInt(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) {
      throw FormatException('Missing required key: $key');
    }
    final value = map[key];
    if (value is! int) {
      throw FormatException('Invalid type for key: $key (expected int)');
    }
    return value;
  }

  factory SessionData.fromMap(Map<dynamic, dynamic> map) {
    final username = _readString(map, 'username');
    if (!RealTimeDb.isValidUsername(username)) {
      throw FormatException('Invalid username format: $username');
    }
    final tenantId = _readString(map, 'tenantId');
    final deviceId = _readString(map, 'deviceId');

    final startedAtMillis = _readInt(map, 'startedAt');
    if (startedAtMillis <= 0) {
      throw FormatException('Invalid startedAt value: $startedAtMillis');
    }

    DateTime? lastActiveAt;
    if (map.containsKey('lastActiveAt') && map['lastActiveAt'] != null) {
      final raw = map['lastActiveAt'];
      if (raw is! int) {
        throw FormatException(
          'Invalid type for key: lastActiveAt (expected int or null)',
        );
      }
      lastActiveAt = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    var isActive = false;
    if (map.containsKey('isActive') && map['isActive'] != null) {
      final raw = map['isActive'];
      if (raw is! bool) {
        throw FormatException('Invalid type for key: isActive (expected bool)');
      }
      isActive = raw;
    }

    return SessionData(
      username: username,
      tenantId: tenantId,
      deviceId: deviceId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMillis),
      lastActiveAt: lastActiveAt,
      isActive: isActive,
    );
  }

  SessionData copyWith({
    String? username,
    String? tenantId,
    String? deviceId,
    DateTime? startedAt,
    DateTime? lastActiveAt,
    bool? isActive,
  }) {
    return SessionData(
      username: username ?? this.username,
      tenantId: tenantId ?? this.tenantId,
      deviceId: deviceId ?? this.deviceId,
      startedAt: startedAt ?? this.startedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionData &&
        other.username == username &&
        other.tenantId == tenantId &&
        other.deviceId == deviceId &&
        other.startedAt == startedAt &&
        other.lastActiveAt == lastActiveAt &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
    username,
    tenantId,
    deviceId,
    startedAt,
    lastActiveAt,
    isActive,
  );

  @override
  String toString() =>
      'SessionData(username: $username, tenantId: $tenantId, deviceId: $deviceId, startedAt: $startedAt, lastActiveAt: $lastActiveAt, isActive: $isActive)';
}

/// Real-time database service for session tracking by username within tenant.
///
/// Uses Firebase Realtime Database to track active sessions per username
/// within a tenant (business). The tenant ID is derived from the
/// Firebase Auth UID of the business owner.
class RealTimeDb {
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  static bool isValidUsername(String username) =>
      usernamePattern.hasMatch(username);

  final DatabaseReference _database;
  final String _tenantId;

  /// Creates a new [RealTimeDb] instance.
  ///
  /// [database] is the Firebase Database instance.
  /// [tenantId] is the Firebase UID of the business owner/tenant.
  RealTimeDb({required DatabaseReference database, required String tenantId})
    : _database = database,
      _tenantId = tenantId;

  /// Minimal login/logout integration: derives the tenant from auth.
  ///
  /// No Bloc coupling by design — callers recreate [RealTimeDb] via this
  /// factory on `FirebaseAuthService.authStateChanges` (login creates a new
  /// instance, logout disposes it). A full Bloc-level wiring was deliberately
  /// avoided here to keep this branch free of deep auth-Bloc changes;
  /// that remains a follow-up if session tracking ever needs to react to
  /// auth state internally.
  ///
  /// Throws [StateError] when no user is signed in (empty tenant id).
  factory RealTimeDb.fromAuth({
    required DatabaseReference database,
    required FirebaseAuthService authService,
  }) {
    final tenantId = authService.getCurrentTenantId();
    if (tenantId.isEmpty) {
      throw StateError(
        'Cannot create RealTimeDb: no authenticated user (empty tenant id). '
        'Create it after login via authStateChanges.',
      );
    }
    return RealTimeDb(database: database, tenantId: tenantId);
  }

  /// Gets the database reference for the current tenant's sessions.
  DatabaseReference get _sessionsRef =>
      _database.child('tenants').child(_tenantId).child('sessions');

  static ValidationFailure? usernameFailure(String username) {
    if (username.isEmpty) {
      return const ValidationFailure(
        'Username cannot be empty',
        field: 'username',
        reason: 'empty',
      );
    }
    if (!isValidUsername(username)) {
      return const ValidationFailure(
        'Username must be 3-30 chars: letters, digits, underscore',
        field: 'username',
        reason: 'invalid-format',
      );
    }
    return null;
  }

  static ValidationFailure? deviceIdFailure(String deviceId) {
    if (deviceId.isEmpty) {
      return const ValidationFailure(
        'Device ID cannot be empty',
        field: 'deviceId',
        reason: 'empty',
      );
    }
    return null;
  }

  static SessionData parseSnapshotValue(Object? value) {
    if (value is! Map<dynamic, dynamic>) {
      throw FormatException(
        'Invalid session payload (expected Map, got ${value.runtimeType})',
      );
    }
    return SessionData.fromMap(value);
  }

  /// Creates a new session for a username on a device.
  ///
  /// Returns the created [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData>> createSession({
    required String username,
    required String deviceId,
  }) async {
    final userError = usernameFailure(username);
    if (userError != null) return Left(userError);
    final deviceError = deviceIdFailure(deviceId);
    if (deviceError != null) return Left(deviceError);

    try {
      final now = DateTime.now();
      final sessionRef = _sessionsRef.child(username).child(deviceId);

      final sessionData = SessionData(
        username: username,
        tenantId: _tenantId,
        deviceId: deviceId,
        startedAt: now,
        lastActiveAt: now,
        isActive: true,
      );

      await sessionRef.set(sessionData.toMap());

      return Right(sessionData);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to create session: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to create session: $e', cause: e));
    }
  }

  // TODO(post-merge): switch activity/end updates to runTransaction.
  // Deferred because each session key is single-writer per device (heartbeat
  // + end), so read-then-update has no real contention today; moving to
  // transactions needs transaction-handler API verification (incl. offline
  // behavior) plus dedicated contention tests. Kept out of this branch
  // deliberately to avoid scope creep.

  /// Updates the last active timestamp for a session.
  ///
  /// Returns the updated [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData>> updateSessionActivity({
    required String username,
    required String deviceId,
  }) async {
    final userError = usernameFailure(username);
    if (userError != null) return Left(userError);
    final deviceError = deviceIdFailure(deviceId);
    if (deviceError != null) return Left(deviceError);

    try {
      final now = DateTime.now();
      final sessionRef = _sessionsRef.child(username).child(deviceId);

      final snapshot = await sessionRef.get();
      if (!snapshot.exists) {
        return Left(DatabaseFailure('Session not found for user: $username'));
      }

      final existingData = parseSnapshotValue(snapshot.value);
      final updatedData = existingData.copyWith(lastActiveAt: now);

      await sessionRef.update(updatedData.toMap());

      return Right(updatedData);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(
        DatabaseFailure('Failed to update session activity: $e', cause: e),
      );
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to update session activity: $e', cause: e),
      );
    }
  }

  /// Ends a session for a username on a device.
  ///
  /// Returns the ended [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData>> endSession({
    required String username,
    required String deviceId,
  }) async {
    final userError = usernameFailure(username);
    if (userError != null) return Left(userError);
    final deviceError = deviceIdFailure(deviceId);
    if (deviceError != null) return Left(deviceError);

    try {
      final sessionRef = _sessionsRef.child(username).child(deviceId);

      final snapshot = await sessionRef.get();
      if (!snapshot.exists) {
        return Left(DatabaseFailure('Session not found for user: $username'));
      }

      final existingData = parseSnapshotValue(snapshot.value);
      final endedData = existingData.copyWith(
        isActive: false,
        lastActiveAt: DateTime.now(),
      );

      await sessionRef.update(endedData.toMap());

      return Right(endedData);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to end session: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to end session: $e', cause: e));
    }
  }

  /// Gets the active session for a username on a device.
  ///
  /// Returns the [SessionData] if found and active, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData?>> getSession({
    required String username,
    required String deviceId,
  }) async {
    final userError = usernameFailure(username);
    if (userError != null) return Left(userError);
    final deviceError = deviceIdFailure(deviceId);
    if (deviceError != null) return Left(deviceError);

    try {
      final sessionRef = _sessionsRef.child(username).child(deviceId);
      final snapshot = await sessionRef.get();

      if (!snapshot.exists) {
        return const Right(null);
      }

      final data = parseSnapshotValue(snapshot.value);
      if (!data.isActive) {
        return const Right(null);
      }

      return Right(data);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to get session: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get session: $e', cause: e));
    }
  }

  /// Gets all active sessions for a username across devices.
  ///
  /// Malformed child payloads are skipped so one corrupt device entry
  /// cannot fail the whole read.
  ///
  /// Returns a list of [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, List<SessionData>>> getActiveSessionsForUser({
    required String username,
  }) async {
    final userError = usernameFailure(username);
    if (userError != null) return Left(userError);

    try {
      final userSessionsRef = _sessionsRef.child(username);
      final snapshot = await userSessionsRef.get();

      if (!snapshot.exists) {
        return const Right([]);
      }

      final sessions = <SessionData>[];
      final children = snapshot.children;
      for (final child in children) {
        try {
          final data = parseSnapshotValue(child.value);
          if (data.isActive) {
            sessions.add(data);
          }
        } on FormatException {
          continue;
        } catch (_) {
          continue;
        }
      }

      return Right(sessions);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(
        DatabaseFailure('Failed to get active sessions: $e', cause: e),
      );
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get active sessions: $e', cause: e),
      );
    }
  }

  /// Gets all active sessions across all users in the tenant.
  ///
  /// Malformed child payloads are skipped so one corrupt entry cannot
  /// fail the whole read.
  ///
  /// Returns a list of [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, List<SessionData>>> getAllActiveSessions() async {
    try {
      final snapshot = await _sessionsRef.get();

      if (!snapshot.exists) {
        return const Right([]);
      }

      final sessions = <SessionData>[];
      final users = snapshot.children;
      for (final user in users) {
        final devices = user.children;
        for (final device in devices) {
          try {
            final data = parseSnapshotValue(device.value);
            if (data.isActive) {
              sessions.add(data);
            }
          } on FormatException {
            continue;
          } catch (_) {
            continue;
          }
        }
      }

      return Right(sessions);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(
        DatabaseFailure('Failed to get all active sessions: $e', cause: e),
      );
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to get all active sessions: $e', cause: e),
      );
    }
  }

  /// Stream of active sessions for a specific username.
  ///
  /// Malformed children are skipped; stream-level errors are surfaced via
  /// [Stream.handleError] downstream instead of crashing the subscription.
  /// Invalid usernames yield [Stream.error] with a [ValidationFailure].
  Stream<List<SessionData>> watchActiveSessionsForUser(String username) async* {
    final userError = usernameFailure(username);
    if (userError != null) {
      yield* Stream.error(userError);
      return;
    }
    try {
      await for (final event in _sessionsRef.child(username).onValue) {
        try {
          if (!event.snapshot.exists) {
            yield <SessionData>[];
            continue;
          }
          final sessions = <SessionData>[];
          for (final child in event.snapshot.children) {
            try {
              final data = parseSnapshotValue(child.value);
              if (data.isActive) {
                sessions.add(data);
              }
            } on FormatException {
              continue;
            } catch (_) {
              continue;
            }
          }
          yield sessions;
        } on FormatException {
          yield <SessionData>[];
        } catch (_) {
          yield <SessionData>[];
        }
      }
    } catch (_) {
      yield <SessionData>[];
    }
  }

  /// Stream of all active sessions across all users in the tenant.
  ///
  /// Malformed children are skipped; stream-level errors emit an empty list
  /// instead of crashing the subscription.
  Stream<List<SessionData>> watchAllActiveSessions() async* {
    try {
      await for (final event in _sessionsRef.onValue) {
        try {
          if (!event.snapshot.exists) {
            yield <SessionData>[];
            continue;
          }
          final sessions = <SessionData>[];
          for (final user in event.snapshot.children) {
            for (final device in user.children) {
              try {
                final data = parseSnapshotValue(device.value);
                if (data.isActive) {
                  sessions.add(data);
                }
              } on FormatException {
                continue;
              } catch (_) {
                continue;
              }
            }
          }
          yield sessions;
        } on FormatException {
          yield <SessionData>[];
        } catch (_) {
          yield <SessionData>[];
        }
      }
    } catch (_) {
      yield <SessionData>[];
    }
  }

  /// Cleans up inactive sessions older than [maxAge].
  ///
  /// Malformed child payloads are skipped.
  ///
  /// Returns the number of cleaned up sessions on success, or [DatabaseFailure] on error.
  Future<Either<Failure, int>> cleanupInactiveSessions({
    required Duration maxAge,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(maxAge);
      final snapshot = await _sessionsRef.get();

      if (!snapshot.exists) {
        return const Right(0);
      }

      var cleaned = 0;
      for (final user in snapshot.children) {
        for (final device in user.children) {
          try {
            final data = parseSnapshotValue(device.value);
            if (!data.isActive &&
                data.lastActiveAt != null &&
                data.lastActiveAt!.isBefore(cutoff)) {
              await device.ref.remove();
              cleaned++;
            }
          } on FormatException {
            continue;
          } catch (_) {
            continue;
          }
        }
      }

      return Right(cleaned);
    } on FormatException catch (e) {
      return Left(DatabaseFailure('Invalid session data: $e', cause: e));
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to cleanup sessions: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to cleanup sessions: $e', cause: e));
    }
  }
}
