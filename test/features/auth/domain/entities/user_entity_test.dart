import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';

void main() {
  group('UserEntity', () {
    final now = DateTime.now();
    final user = UserEntity(
      username: 'testuser',
      passwordHash: 'hash123',
      passwordSalt: 'salt123',
      mustChangePassword: true,
      role: UserRole.cashier,
      createdAt: now,
    );

    test('should create with default values', () {
      final u = UserEntity(
        username: 'minimal',
        passwordHash: 'h',
        role: UserRole.admin,
        createdAt: now,
      );
      expect(u.passwordSalt, isNotEmpty);
      expect(u.mustChangePassword, false);
    });

    test('copyWith should override fields', () {
      final modified = user.copyWith(
        username: 'newuser',
        passwordHash: 'newhash',
        mustChangePassword: false,
        role: UserRole.admin,
      );
      expect(modified.username, 'newuser');
      expect(modified.passwordHash, 'newhash');
      expect(modified.mustChangePassword, false);
      expect(modified.role, UserRole.admin);
      expect(modified.createdAt, user.createdAt);
    });

    test('copyWith should preserve unset fields', () {
      final modified = user.copyWith(username: 'onlyuser');
      expect(modified.username, 'onlyuser');
      expect(modified.passwordHash, user.passwordHash);
      expect(modified.passwordSalt, user.passwordSalt);
      expect(modified.mustChangePassword, user.mustChangePassword);
      expect(modified.role, user.role);
      expect(modified.createdAt, user.createdAt);
    });

    test('equality should work', () {
      final same = UserEntity(
        username: 'testuser',
        passwordHash: 'hash123',
        passwordSalt: 'salt123',
        mustChangePassword: true,
        role: UserRole.cashier,
        createdAt: now,
      );
      final different = UserEntity(
        username: 'other',
        passwordHash: 'hash',
        role: UserRole.admin,
        createdAt: now,
      );
      expect(same == user, isTrue);
      expect(same.hashCode, user.hashCode);
      expect(different == user, isFalse);
    });
  });
}
