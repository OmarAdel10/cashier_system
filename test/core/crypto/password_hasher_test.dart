import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/crypto/password_hasher.dart';

void main() {
  group('generateSalt', () {
    test('should return base64url string of length 24', () {
      final salt = generateSalt();
      expect(salt, isA<String>());
      expect(salt.length, 44);
    });

    test('should produce different salts on each call', () {
      final salt1 = generateSalt();
      final salt2 = generateSalt();
      expect(salt1, isNot(equals(salt2)));
    });
  });

  group('hashPassword', () {
    test('should produce deterministic hash for same password and salt', () {
      const password = 'test1234';
      final salt = generateSalt();
      final hash1 = hashPassword(password, salt);
      final hash2 = hashPassword(password, salt);
      expect(hash1, equals(hash2));
    });

    test('should produce different hashes for different passwords', () {
      final salt = generateSalt();
      final hash1 = hashPassword('password1', salt);
      final hash2 = hashPassword('password2', salt);
      expect(hash1, isNot(equals(hash2)));
    });

    test('should produce different hashes for different salts', () {
      final salt1 = generateSalt();
      final salt2 = generateSalt();
      final hash1 = hashPassword('password', salt1);
      final hash2 = hashPassword('password', salt2);
      expect(hash1, isNot(equals(hash2)));
    });

    test('should return base64 encoded string of length 44', () {
      final salt = generateSalt();
      final hash = hashPassword('password', salt);
      expect(hash, isA<String>());
      expect(hash.length, 44);
    });
  });

  group('hashTagged (pbkdf2-sha512)', () {
    test('round-trips and parses the scheme tag', () {
      final stored = hashTagged(
        'abc123',
        iterations: 1000,
        saltB64Url: 'c2FsdHNhbHQ',
      );
      final parts = stored.split(r'$');
      expect(parts, hasLength(4));
      expect(parts[0], 'pbkdf2-sha512');
      expect(parts[1], '1000');
      expect(parts[2], 'c2FsdHNhbHQ');
      expect(parts[3], hasLength(44));
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });

    test('rejects wrong password and malformed stored values', () {
      final stored = hashTagged(
        'abc123',
        iterations: 1000,
        saltB64Url: 'c2FsdHNhbHQ',
      );
      expect(verifyTagged(stored, 'wrong'), isFalse);
      expect(verifyTagged('garbage', 'x'), isFalse);
      expect(verifyTagged(r'pbkdf2-sha512$0$salt$hash', 'x'), isFalse);
      expect(verifyTagged(r'argon2id$16$1$1$salt$hash', 'x'), isFalse);
      expect(
        verifyTagged(r'pbkdf2-sha512$1$!!not-base64!!$hash', 'x'),
        isFalse,
      );
    });

    test('generates salt when omitted; arabic password round-trip', () {
      final stored = hashTagged('سلام123', iterations: 1000);
      expect(isTagged(stored), isTrue);
      expect(isTagged('plainLegacyHash'), isFalse);
      expect(stored.split(r'$')[2], hasLength(44));
      expect(verifyTagged(stored, 'سلام123'), isTrue);
      expect(verifyTagged(stored, 'سلام124'), isFalse);
    });

    test('padded salts from the TS worker also verify', () {
      final stored = hashTagged(
        'abc123',
        iterations: 1000,
        saltB64Url: 'c2FsdHNhbHQ=',
      );
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });
  });

  group('hashTagged edge cases & fixture oracle', () {
    test('reproduces the frozen values in kdf_vectors.json', () {
      final vectors =
          (jsonDecode(
                    File(
                      'backend/shared/fixtures/kdf_vectors.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      expect(vectors, hasLength(5));
      for (final v in vectors) {
        expect(v.keys.toSet(), {
          'password',
          'iterations',
          'salt_b64url',
          'expected',
        });
        expect(
          hashTagged(
            v['password'] as String,
            iterations: v['iterations'] as int,
            saltB64Url: v['salt_b64url'] as String,
          ),
          equals(v['expected']),
        );
      }
    });

    test('rejects four-part stored values with a different scheme', () {
      expect(
        verifyTagged(r'pbkdf2-sha256$1000$c2FsdHNhbHQ$hash', 'x'),
        isFalse,
      );
      expect(verifyTagged(r'scrypt$16384$salt$hash', 'x'), isFalse);
    });

    test('rejects non-numeric, negative, and oversized iterations', () {
      expect(verifyTagged(r'pbkdf2-sha512$abc$c2FsdHNhbHQ$hash', 'x'), isFalse);
      expect(verifyTagged(r'pbkdf2-sha512$-1$c2FsdHNhbHQ$hash', 'x'), isFalse);
      expect(
        verifyTagged(r'pbkdf2-sha512$1000001$c2FsdHNhbHQ$hash', 'x'),
        isFalse,
      );
    });

    test('rejects stored values whose hash segment has the wrong length', () {
      const stored = r'pbkdf2-sha512$1000$c2FsdHNhbHQ$';
      expect(isTagged(stored), isTrue);
      expect(verifyTagged(stored, 'abc123'), isFalse);
    });

    test('rejects stored values with a trailing extra segment', () {
      expect(
        verifyTagged(r'pbkdf2-sha512$1000$c2FsdHNhbHQ$hash$extra', 'x'),
        isFalse,
      );
    });

    test('defaults to 50000 iterations when none are given', () {
      final stored = hashTagged('abc123', saltB64Url: 'c2FsdHNhbHQ');
      expect(stored.split(r'$')[1], '50000');
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });

    test('isTagged requires the full prefix including the delimiter', () {
      expect(isTagged('pbkdf2-sha512foo'), isFalse);
      expect(isTagged('pbkdf2-sha512'), isFalse);
      expect(isTagged(r'pbkdf2-sha512$'), isTrue);
    });

    test('hashTagged propagates malformed-salt FormatException', () {
      expect(
        () => hashTagged('abc123', iterations: 1000, saltB64Url: 'A'),
        throwsFormatException,
      );
      expect(
        () => hashTagged(
          'abc123',
          iterations: 1000,
          saltB64Url: '!!not-base64!!',
        ),
        throwsFormatException,
      );
    });

    test('zero iterations yield a stored value verifyTagged rejects', () {
      final stored = hashTagged(
        'abc123',
        iterations: 0,
        saltB64Url: 'c2FsdHNhbHQ',
      );
      expect(isTagged(stored), isTrue);
      expect(verifyTagged(stored, 'abc123'), isFalse);
    });

    test('round-trips an empty password', () {
      final stored = hashTagged(
        '',
        iterations: 1000,
        saltB64Url: 'c2FsdHNhbHQ',
      );
      expect(verifyTagged(stored, ''), isTrue);
      expect(verifyTagged(stored, 'x'), isFalse);
    });

    test('tolerates an empty salt segment', () {
      final stored = hashTagged('abc123', iterations: 1000, saltB64Url: '');
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });

    test('verifies a single PBKDF2 iteration', () {
      final stored = hashTagged(
        'abc123',
        iterations: 1,
        saltB64Url: 'c2FsdHNhbHQ',
      );
      expect(stored.split(r'$')[1], '1');
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });

    test('verifies salts that need two padding characters', () {
      final stored = hashTagged(
        'abc123',
        iterations: 1000,
        saltB64Url: 'MTIzNDU2Nzg5MGFiY2RlZg',
      );
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });

    test('verifies at exactly the 1000000-iteration cap', () {
      // The cap is `> 1000000`: exactly one million must still verify.
      // Frozen vector (crypto 3.0.7); regenerable via tool/gen_kdf_fixtures.dart.
      const stored =
          r'pbkdf2-sha512$1000000$c2FsdHNhbHQ$tgutnHDhzzaLJy0Xrnm99xBJsSwvGjo5/8WUXUFvgNg=';
      expect(verifyTagged(stored, 'abc123'), isTrue);
    });
  });
}
