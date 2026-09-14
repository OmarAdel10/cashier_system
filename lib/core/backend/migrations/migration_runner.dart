// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:flutter/foundation.dart';
import 'migration.dart';

/// Exception thrown when a migration fails.
class MigrationFailure implements Exception {
  /// The migration version that failed.
  final int version;

  /// Error message describing the failure.
  final String message;

  /// The original exception, if any.
  final Object? originalError;

  /// Stack trace from the original error.
  final StackTrace? stackTrace;

  const MigrationFailure({
    required this.version,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'MigrationFailure(V$version): $message';
}

/// Snapshot of database migration state.
class MigrationStateSnapshot {
  /// List of applied migration versions in order.
  final List<int> appliedVersions;

  /// Current schema version (highest applied).
  final int currentVersion;

  const MigrationStateSnapshot({
    required this.appliedVersions,
    required this.currentVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MigrationStateSnapshot &&
        _listEquals(other.appliedVersions, appliedVersions) &&
        other.currentVersion == currentVersion;
  }

  @override
  int get hashCode => Object.hashAll([...appliedVersions, currentVersion]);

  @override
  String toString() =>
      'MigrationStateSnapshot(applied: $appliedVersions, current: $currentVersion)';

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Result of a migration run.
class MigrationResult {
  /// Migrations that were planned but not executed (dry-run mode).
  final List<Migration> planned;

  /// Migrations that were actually executed.
  final List<Migration> executed;

  /// Whether the run was a dry-run.
  final bool dryRun;

  const MigrationResult({
    required this.planned,
    required this.executed,
    required this.dryRun,
  });

  @override
  String toString() =>
      'MigrationResult(dryRun: $dryRun, planned: ${planned.length}, executed: ${executed.length})';
}

/// Runs database migrations with support for dry-run, retry logic, and rollback.
class MigrationRunner {
  /// All registered migrations, sorted by version.
  final List<Migration> _migrations;

  /// Maximum number of retry attempts for failed migrations.
  final int maxRetries;

  /// Base delay for exponential backoff.
  final Duration baseRetryDelay;

  /// Tracks which migrations have been applied.
  final Set<int> _appliedVersions = <int>{};

  /// Creates a MigrationRunner with the given migrations.
  ///
  /// Migrations are automatically sorted by version.
  /// [maxRetries] defaults to 3.
  /// [baseRetryDelay] defaults to 100ms.
  MigrationRunner({
    required List<Migration> migrations,
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(milliseconds: 100),
  }) : _migrations = List<Migration>.from(migrations)
         ..sort((a, b) => a.version.compareTo(b.version));

  /// Returns all registered migrations sorted by version.
  List<Migration> get migrations => List.unmodifiable(_migrations);

  /// Runs all pending migrations.
  ///
  /// If [dryRun] is true, returns a plan without executing.
  /// If [dryRun] is false (default), executes all pending migrations.
  Future<MigrationResult> runMigrations({bool dryRun = false}) async {
    final pending = _getPendingMigrations();

    if (dryRun) {
      return MigrationResult(
        planned: pending,
        executed: const [],
        dryRun: true,
      );
    }

    final executed = <Migration>[];

    for (final migration in pending) {
      await _executeWithRetry(migration);
      _appliedVersions.add(migration.version);
      executed.add(migration);
    }

    return MigrationResult(
      planned: const [],
      executed: executed,
      dryRun: false,
    );
  }

  /// Rolls back the last [steps] applied migrations.
  ///
  /// Throws [MigrationFailure] if there are not enough migrations to roll back.
  Future<void> rollback({int steps = 1}) async {
    if (steps <= 0) {
      throw ArgumentError('steps must be positive');
    }

    final applied = _getAppliedMigrations();
    if (applied.length < steps) {
      throw MigrationFailure(
        version: 0,
        message:
            'Cannot rollback $steps steps: only ${applied.length} migrations applied',
      );
    }

    // Roll back in reverse order
    final toRollback = applied.reversed.take(steps).toList();

    for (final migration in toRollback) {
      try {
        await migration.down();
      } catch (e, st) {
        throw MigrationFailure(
          version: migration.version,
          message: 'Rollback failed: $e',
          originalError: e,
          stackTrace: st,
        );
      }
      _appliedVersions.remove(migration.version);
    }
  }

  /// Returns a snapshot of the current migration state.
  MigrationStateSnapshot getDatabaseStateSnapshot() {
    final applied = _getAppliedMigrations();
    return MigrationStateSnapshot(
      appliedVersions: applied.map((m) => m.version).toList(),
      currentVersion: applied.isEmpty ? 0 : applied.last.version,
    );
  }

  /// Resets the runner state (for testing only).
  @visibleForTesting
  void resetForTests() {
    _appliedVersions.clear();
  }

  List<Migration> _getPendingMigrations() {
    return _migrations
        .where((m) => !_appliedVersions.contains(m.version))
        .toList();
  }

  List<Migration> _getAppliedMigrations() {
    return _migrations
        .where((m) => _appliedVersions.contains(m.version))
        .toList();
  }

  Future<void> _executeWithRetry(Migration migration) async {
    var attempt = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempt <= maxRetries) {
      try {
        await migration.up();
        return; // Success
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
        attempt++;

        if (attempt <= maxRetries) {
          // Exponential backoff: baseDelay * 2^(attempt-1)
          final delay = baseRetryDelay * (1 << (attempt - 1));
          await Future.delayed(delay);
        }
      }
    }

    // All retries exhausted
    throw MigrationFailure(
      version: migration.version,
      message: 'Migration failed after ${maxRetries + 1} attempts: $lastError',
      originalError: lastError,
      stackTrace: lastStackTrace,
    );
  }
}
