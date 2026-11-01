import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:daftari/core/crypto/password_hasher.dart';

void main() {
  const fixturePath = '../../backend/shared/fixtures/kdf_vectors.json';
  const scriptPath = 'tool/gen_kdf_fixtures.dart';

  group('gen_kdf_fixtures', () {
    late String originalContent;

    setUp(() {
      originalContent = File(fixturePath).readAsStringSync();
    });

    tearDown(() {
      File(fixturePath).writeAsStringSync(originalContent);
    });

    test('main() writes valid JSON fixture with 5 vectors', () {
      final result = Process.runSync('dart', [scriptPath]);
      expect(
        result.exitCode,
        0,
        reason:
            'gen_kdf_fixtures.dart exited ${result.exitCode}: ${result.stderr}',
      );

      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);

      final vectors = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(vectors.length, 5);

      for (final v in vectors) {
        final map = v as Map<String, dynamic>;
        expect(map.keys.toSet(), {
          'password',
          'iterations',
          'salt_b64url',
          'expected',
        });
      }
    });

    test('main() is idempotent — re-run produces identical output', () {
      Process.runSync('dart', [scriptPath]);
      final first = File(fixturePath).readAsStringSync();
      Process.runSync('dart', [scriptPath]);
      final second = File(fixturePath).readAsStringSync();
      expect(second, equals(first));
    });

    test('each expected hash matches hashTagged round-trip', () {
      Process.runSync('dart', [scriptPath]);

      final vectors = jsonDecode(File(fixturePath).readAsStringSync()) as List;

      for (final v in vectors) {
        final map = v as Map<String, dynamic>;
        final expected = hashTagged(
          map['password'] as String,
          iterations: map['iterations'] as int,
          saltB64Url: map['salt_b64url'] as String,
        );
        expect(map['expected'], equals(expected));
      }
    });

    test('fixture values are pinned per vector index', () {
      Process.runSync('dart', [scriptPath]);

      final vectors = jsonDecode(File(fixturePath).readAsStringSync()) as List;

      expect((vectors[0] as Map)['password'], 'abc123');
      expect((vectors[0] as Map)['iterations'], 1000);
      expect((vectors[0] as Map)['salt_b64url'], 'c2FsdHNhbHQ');

      expect((vectors[1] as Map)['password'], 'سلام123');
      expect((vectors[1] as Map)['iterations'], 1000);
      expect((vectors[1] as Map)['salt_b64url'], 'c2FsdHNhbHQ');

      expect((vectors[2] as Map)['password'], 'p@ssw0rd!9');
      expect((vectors[2] as Map)['iterations'], 5000);
      expect((vectors[2] as Map)['salt_b64url'], 'c2hvcnQ');

      expect(
        (vectors[3] as Map)['password'],
        'a-very-long-password-with-ن-و-ع-و-م-ر-06',
      );
      expect((vectors[3] as Map)['iterations'], 1000);
      expect((vectors[3] as Map)['salt_b64url'], 'MTIzNDU2Nzg5MGFiY2RlZg');

      expect((vectors[4] as Map)['password'], 'abc123');
      expect((vectors[4] as Map)['iterations'], 1000);
      expect((vectors[4] as Map)['salt_b64url'], 'c2FsdHNhbHQ=');
    });

    test('main() surfaces a clear failure when output dir is unwritable', () {
      // Make the fixtures directory read-only via chmod
      final chmodResult = Process.runSync('chmod', [
        '555',
        '../../backend/shared/fixtures',
      ]);
      expect(
        chmodResult.exitCode,
        0,
        reason: 'chmod 555 failed: ${chmodResult.stderr}',
      );

      try {
        final result = Process.runSync('dart', [scriptPath]);
        expect(
          result.exitCode,
          isNot(0),
          reason:
              'expected non-zero exit when fixtures dir is unwritable, got ${result.exitCode}',
        );
      } finally {
        // Restore write permission so tearDown can restore the fixture file
        Process.runSync('chmod', ['755', '../../backend/shared/fixtures']);
      }
    });
  });
}
