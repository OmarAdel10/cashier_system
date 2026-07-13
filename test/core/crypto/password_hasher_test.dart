import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/crypto/password_hasher.dart';

void main() {
  group('generateSalt', () {
    test('should return base64url string of length 24', () {
      final salt = generateSalt();
      expect(salt, isA<String>());
      expect(salt.length, 24);
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
      const salt = 'test_salt_value_123';
      final hash1 = hashPassword(password, salt);
      final hash2 = hashPassword(password, salt);
      expect(hash1, equals(hash2));
    });

    test('should produce different hashes for different passwords', () {
      const salt = 'test_salt_value_123';
      final hash1 = hashPassword('password1', salt);
      final hash2 = hashPassword('password2', salt);
      expect(hash1, isNot(equals(hash2)));
    });

    test('should produce different hashes for different salts', () {
      final hash1 = hashPassword('password', 'salt1');
      final hash2 = hashPassword('password', 'salt2');
      expect(hash1, isNot(equals(hash2)));
    });

    test('should return base64 encoded string of length 44', () {
      final hash = hashPassword('password', 'salt');
      expect(hash, isA<String>());
      expect(hash.length, 44);
    });
  });
}
