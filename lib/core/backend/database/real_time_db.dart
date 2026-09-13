// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_database/firebase_database.dart';
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

  factory SessionData.fromMap(Map<dynamic, dynamic> map) {
    return SessionData(
      username: map['username'] as String,
      tenantId: map['tenantId'] as String,
      deviceId: map['deviceId'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt'] as int)
          : null,
      isActive: map['isActive'] as bool? ?? false,
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
  final DatabaseReference _database;
  final String _tenantId;

  /// Creates a new [RealTimeDb] instance.
  ///
  /// [database] is the Firebase Database instance.
  /// [tenantId] is the Firebase UID of the business owner/tenant.
  RealTimeDb({required DatabaseReference database, required String tenantId})
    : _database = database,
      _tenantId = tenantId;

  /// Gets the database reference for the current tenant's sessions.
  DatabaseReference get _sessionsRef =>
      _database.child('tenants').child(_tenantId).child('sessions');

  /// Creates a new session for a username on a device.
  ///
  /// Returns the created [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData>> createSession({
    required String username,
    required String deviceId,
  }) async {
    if (username.isEmpty) {
      return Left(
        ValidationFailure(
          'Username cannot be empty',
          field: 'username',
          reason: 'empty',
        ),
      );
    }
    if (deviceId.isEmpty) {
      return Left(
        ValidationFailure(
          'Device ID cannot be empty',
          field: 'deviceId',
          reason: 'empty',
        ),
      );
    }

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
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to create session: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to create session: $e', cause: e));
    }
  }

  /// Updates the last active timestamp for a session.
  ///
  /// Returns the updated [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, SessionData>> updateSessionActivity({
    required String username,
    required String deviceId,
  }) async {
    if (username.isEmpty) {
      return Left(
        ValidationFailure(
          'Username cannot be empty',
          field: 'username',
          reason: 'empty',
        ),
      );
    }
    if (deviceId.isEmpty) {
      return Left(
        ValidationFailure(
          'Device ID cannot be empty',
          field: 'deviceId',
          reason: 'empty',
        ),
      );
    }

    try {
      final now = DateTime.now();
      final sessionRef = _sessionsRef.child(username).child(deviceId);

      final snapshot = await sessionRef.get();
      if (!snapshot.exists) {
        return Left(DatabaseFailure('Session not found for user: $username'));
      }

      final existingData = SessionData.fromMap(
        snapshot.value as Map<dynamic, dynamic>,
      );
      final updatedData = existingData.copyWith(lastActiveAt: now);

      await sessionRef.update(updatedData.toMap());

      return Right(updatedData);
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
    if (username.isEmpty) {
      return Left(
        ValidationFailure(
          'Username cannot be empty',
          field: 'username',
          reason: 'empty',
        ),
      );
    }
    if (deviceId.isEmpty) {
      return Left(
        ValidationFailure(
          'Device ID cannot be empty',
          field: 'deviceId',
          reason: 'empty',
        ),
      );
    }

    try {
      final sessionRef = _sessionsRef.child(username).child(deviceId);

      final snapshot = await sessionRef.get();
      if (!snapshot.exists) {
        return Left(DatabaseFailure('Session not found for user: $username'));
      }

      final existingData = SessionData.fromMap(
        snapshot.value as Map<dynamic, dynamic>,
      );
      final endedData = existingData.copyWith(
        isActive: false,
        lastActiveAt: DateTime.now(),
      );

      await sessionRef.update(endedData.toMap());

      return Right(endedData);
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
    if (username.isEmpty) {
      return Left(
        ValidationFailure(
          'Username cannot be empty',
          field: 'username',
          reason: 'empty',
        ),
      );
    }
    if (deviceId.isEmpty) {
      return Left(
        ValidationFailure(
          'Device ID cannot be empty',
          field: 'deviceId',
          reason: 'empty',
        ),
      );
    }

    try {
      final sessionRef = _sessionsRef.child(username).child(deviceId);
      final snapshot = await sessionRef.get();

      if (!snapshot.exists) {
        return const Right(null);
      }

      final data = SessionData.fromMap(snapshot.value as Map<dynamic, dynamic>);
      if (!data.isActive) {
        return const Right(null);
      }

      return Right(data);
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to get session: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to get session: $e', cause: e));
    }
  }

  /// Gets all active sessions for a username across devices.
  ///
  /// Returns a list of [SessionData] on success, or [DatabaseFailure] on error.
  Future<Either<Failure, List<SessionData>>> getActiveSessionsForUser({
    required String username,
  }) async {
    if (username.isEmpty) {
      return Left(
        ValidationFailure(
          'Username cannot be empty',
          field: 'username',
          reason: 'empty',
        ),
      );
    }

    try {
      final userSessionsRef = _sessionsRef.child(username);
      final snapshot = await userSessionsRef.get();

      if (!snapshot.exists) {
        return const Right([]);
      }

      final sessions = <SessionData>[];
      final children = snapshot.children;
      for (final child in children) {
        final data = SessionData.fromMap(child.value as Map<dynamic, dynamic>);
        if (data.isActive) {
          sessions.add(data);
        }
      }

      return Right(sessions);
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
          final data = SessionData.fromMap(
            device.value as Map<dynamic, dynamic>,
          );
          if (data.isActive) {
            sessions.add(data);
          }
        }
      }

      return Right(sessions);
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
  Stream<List<SessionData>> watchActiveSessionsForUser(String username) {
    return _sessionsRef.child(username).onValue.map((event) {
      if (!event.snapshot.exists) return <SessionData>[];

      final sessions = <SessionData>[];
      for (final child in event.snapshot.children) {
        final data = SessionData.fromMap(child.value as Map<dynamic, dynamic>);
        if (data.isActive) {
          sessions.add(data);
        }
      }
      return sessions;
    });
  }

  /// Stream of all active sessions across all users in the tenant.
  Stream<List<SessionData>> watchAllActiveSessions() {
    return _sessionsRef.onValue.map((event) {
      if (!event.snapshot.exists) return <SessionData>[];

      final sessions = <SessionData>[];
      for (final user in event.snapshot.children) {
        for (final device in user.children) {
          final data = SessionData.fromMap(
            device.value as Map<dynamic, dynamic>,
          );
          if (data.isActive) {
            sessions.add(data);
          }
        }
      }
      return sessions;
    });
  }

  /// Cleans up inactive sessions older than [maxAge].
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

      int cleaned = 0;
      for (final user in snapshot.children) {
        for (final device in user.children) {
          final data = SessionData.fromMap(
            device.value as Map<dynamic, dynamic>,
          );
          if (!data.isActive &&
              data.lastActiveAt != null &&
              data.lastActiveAt!.isBefore(cutoff)) {
            await device.ref.remove();
            cleaned++;
          }
        }
      }

      return Right(cleaned);
    } on Exception catch (e) {
      return Left(DatabaseFailure('Failed to cleanup sessions: $e', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Failed to cleanup sessions: $e', cause: e));
    }
  }
}
