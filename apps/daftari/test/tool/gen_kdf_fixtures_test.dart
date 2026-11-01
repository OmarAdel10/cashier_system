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
  });
}
