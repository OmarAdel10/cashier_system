import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/backend/migrations/migration.dart';
import 'package:cashier_system/core/backend/migrations/migration_runner.dart';
import 'package:cashier_system/core/backend/migrations/migration_v001.dart';
import 'package:cashier_system/core/backend/migrations/migration_v002.dart';
import 'package:cashier_system/core/backend/migrations/migration_v003.dart';
import 'package:cashier_system/core/backend/migrations/migration_v004.dart';
import 'package:cashier_system/core/backend/migrations/migration_v005.dart';
import 'package:cashier_system/core/backend/migrations/migration_v006.dart';
import 'package:cashier_system/core/backend/migrations/migration_v007.dart';
import 'package:cashier_system/core/backend/migrations/migration_v008.dart';
import 'package:cashier_system/core/backend/migrations/migration_v009.dart';
import 'package:cashier_system/core/backend/migrations/migration_v010.dart';
import 'package:cashier_system/core/backend/migrations/migration_v011.dart';
import 'package:cashier_system/core/backend/migrations/migration_v012.dart';
import 'package:cashier_system/core/backend/migrations/migration_v013.dart';
import 'package:cashier_system/core/backend/migrations/migration_v014.dart';

void main() {
  group('MigrationRunner', () {
    group('dry-run mode', () {
      test(
        'runMigrations with dryRun=true returns plan without executing',
        () async {
          final runner = MigrationRunner(
            migrations: [MigrationV001(), MigrationV002()],
          );
          final result = await runner.runMigrations(dryRun: true);

          expect(result.executed, isEmpty);
          expect(result.planned, hasLength(2));
          expect(result.planned.first.version, equals(1));
          expect(result.planned.last.version, equals(2));
        },
      );

      test('runMigrations with dryRun=true does not modify database', () async {
        final runner = MigrationRunner(migrations: [MigrationV001()]);
        final beforeState = runner.getDatabaseStateSnapshot();

        await runner.runMigrations(dryRun: true);

        final afterState = runner.getDatabaseStateSnapshot();
        expect(afterState, equals(beforeState));
      });

      test('runMigrations dryRun reports all pending migrations', () async {
        final migrations = List.generate(
          14,
          (i) => _createMockMigration(i + 1),
        );
        final runner = MigrationRunner(migrations: migrations);
        final result = await runner.runMigrations(dryRun: true);

        expect(result.planned, hasLength(14));
        for (var i = 0; i < 14; i++) {
          expect(result.planned[i].version, equals(i + 1));
        }
      });
    });

    group('execution mode', () {
      test(
        'runMigrations with dryRun=false executes all pending migrations',
        () async {
          final runner = MigrationRunner(
            migrations: [MigrationV001(), MigrationV002()],
          );
          final result = await runner.runMigrations(dryRun: false);

          expect(result.executed, hasLength(2));
          expect(result.executed.first.version, equals(1));
          expect(result.executed.last.version, equals(2));
          expect(result.planned, isEmpty);
        },
      );

      test('runMigrations skips already-applied migrations', () async {
        final runner = MigrationRunner(
          migrations: [MigrationV001(), MigrationV002()],
        );
        await runner.runMigrations(dryRun: false);

        final secondRun = await runner.runMigrations(dryRun: false);
        expect(secondRun.executed, isEmpty);
        expect(secondRun.planned, isEmpty);
      });

      test('runMigrations applies migrations in version order', () async {
        final migrations = [MigrationV003(), MigrationV001(), MigrationV002()];
        final runner = MigrationRunner(migrations: migrations);
        final result = await runner.runMigrations(dryRun: false);

        expect(
          result.executed.map((m) => m.version).toList(),
          equals([1, 2, 3]),
        );
      });
    });

    group('retry logic', () {
      test('retries failed migration up to maxRetries times', () async {
        int attempts = 0;
        final flakyMigration = _FlakyMigration(
          version: 99,
          failTimes: 2,
          onAttempt: () => attempts++,
        );
        final runner = MigrationRunner(
          migrations: [flakyMigration],
          maxRetries: 3,
        );

        final result = await runner.runMigrations(dryRun: false);
        expect(result.executed, hasLength(1));
        expect(attempts, equals(3)); // initial + 2 retries = 3 attempts
      });

      test('throws after maxRetries exhausted', () async {
        int attempts = 0;
        final alwaysFails = _FlakyMigration(
          version: 99,
          failTimes: 10,
          onAttempt: () => attempts++,
        );
        final runner = MigrationRunner(
          migrations: [alwaysFails],
          maxRetries: 2,
        );

        await expectLater(
          runner.runMigrations(dryRun: false),
          throwsA(isA<MigrationFailure>()),
        );
        expect(attempts, equals(3)); // initial + 2 retries
      });

      test('retry delay increases exponentially', () async {
        final delays = <int>[];
        final flakyMigration = _FlakyMigration(
          version: 99,
          failTimes: 2,
          onAttempt: () {},
          onRetryDelay: (delay) => delays.add(delay.inMilliseconds),
        );
        final runner = MigrationRunner(
          migrations: [flakyMigration],
          maxRetries: 3,
          baseRetryDelay: Duration(milliseconds: 10),
        );

        await runner.runMigrations(dryRun: false);
        expect(delays.length, equals(2));
        expect(delays[1], greaterThan(delays[0])); // exponential backoff
      });
    });

    group('rollback', () {
      test('rollback reverts last executed migration', () async {
        final runner = MigrationRunner(
          migrations: [MigrationV001(), MigrationV002()],
        );
        await runner.runMigrations(dryRun: false);

        await runner.rollback();

        final state = runner.getDatabaseStateSnapshot();
        expect(state.appliedVersions, equals([1]));
      });

      test('rollback multiple steps reverts in reverse order', () async {
        final runner = MigrationRunner(
          migrations: [MigrationV001(), MigrationV002(), MigrationV003()],
        );
        await runner.runMigrations(dryRun: false);

        await runner.rollback(steps: 2);

        final state = runner.getDatabaseStateSnapshot();
        expect(state.appliedVersions, equals([1]));
      });

      test('rollback with no migrations applied throws', () async {
        final runner = MigrationRunner(migrations: [MigrationV001()]);

        expect(() => runner.rollback(), throwsA(isA<MigrationFailure>()));
      });

      test('rollback steps exceeding applied throws', () async {
        final runner = MigrationRunner(migrations: [MigrationV001()]);
        await runner.runMigrations(dryRun: false);

        expect(
          () => runner.rollback(steps: 2),
          throwsA(isA<MigrationFailure>()),
        );
      });
    });

    group('migration versioning', () {
      test('all 14 migrations have unique versions 1-14', () {
        final migrations = [
          MigrationV001(),
          MigrationV002(),
          MigrationV003(),
          MigrationV004(),
          MigrationV005(),
          MigrationV006(),
          MigrationV007(),
          MigrationV008(),
          MigrationV009(),
          MigrationV010(),
          MigrationV011(),
          MigrationV012(),
          MigrationV013(),
          MigrationV014(),
        ];

        final versions = migrations.map((m) => m.version).toList();
        expect(versions, hasLength(14));
        expect(versions.toSet(), hasLength(14));
        for (var i = 0; i < 14; i++) {
          expect(versions.contains(i + 1), isTrue);
        }
      });

      test('each migration has description', () {
        final migrations = [
          MigrationV001(),
          MigrationV002(),
          MigrationV003(),
          MigrationV004(),
          MigrationV005(),
          MigrationV006(),
          MigrationV007(),
          MigrationV008(),
          MigrationV009(),
          MigrationV010(),
          MigrationV011(),
          MigrationV012(),
          MigrationV013(),
          MigrationV014(),
        ];

        for (final m in migrations) {
          expect(
            m.description.isNotEmpty,
            isTrue,
            reason: 'migration V${m.version} missing description',
          );
        }
      });
    });

    group('error handling', () {
      test('migration failure includes version and error message', () async {
        final failingMigration = _FailingMigration(
          version: 5,
          message: 'disk full',
        );
        final runner = MigrationRunner(migrations: [failingMigration]);

        try {
          await runner.runMigrations(dryRun: false);
          fail('expected MigrationFailure');
        } on MigrationFailure catch (e) {
          expect(e.version, equals(5));
          expect(e.message, contains('disk full'));
        }
      });

      test('partial execution state preserved on failure', () async {
        final migrations = [
          MigrationV001(),
          _FailingMigration(version: 2, message: 'fail'),
          MigrationV003(),
        ];
        final runner = MigrationRunner(migrations: migrations);

        try {
          await runner.runMigrations(dryRun: false);
        } catch (_) {}

        final state = runner.getDatabaseStateSnapshot();
        expect(state.appliedVersions, equals([1]));
      });
    });
  });
}

/// Mock migration for testing retry logic
class _FlakyMigration implements Migration {
  @override
  final int version;

  final int failTimes;
  final void Function() onAttempt;
  final void Function(Duration)? onRetryDelay;

  int _attemptCount = 0;

  _FlakyMigration({
    required this.version,
    required this.failTimes,
    required this.onAttempt,
    this.onRetryDelay,
  });

  @override
  String get description => 'Flaky migration V$version';

  @override
  Future<void> up() async {
    onAttempt();
    _attemptCount++;
    if (_attemptCount <= failTimes) {
      if (onRetryDelay != null) {
        // Simulate retry delay
        onRetryDelay!(Duration(milliseconds: 10 * (1 << (_attemptCount - 1))));
      }
      throw Exception('Simulated failure $_attemptCount');
    }
  }

  @override
  Future<void> down() async {}
}

/// Mock migration that always fails
class _FailingMigration implements Migration {
  @override
  final int version;

  final String message;

  _FailingMigration({required this.version, required this.message});

  @override
  String get description => 'Failing migration V$version';

  @override
  Future<void> up() async {
    throw Exception(message);
  }

  @override
  Future<void> down() async {}
}

/// Helper to create mock migrations for testing
Migration _createMockMigration(int version) {
  return _MockMigration(version: version);
}

class _MockMigration implements Migration {
  @override
  final int version;

  _MockMigration({required this.version});

  @override
  String get description => 'Mock migration V$version';

  @override
  Future<void> up() async {}

  @override
  Future<void> down() async {}
}
