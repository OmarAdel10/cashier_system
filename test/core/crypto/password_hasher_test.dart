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
}
