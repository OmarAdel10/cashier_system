import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/data/models/app_user_model.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';

void main() {
  group('AppUserModel', () {
    final now = DateTime.now();
    final model = AppUserModel(
      username: 'testuser',
      passwordHash: 'hash123',
      passwordSalt: 'salt123',
      mustChangePassword: true,
      role: UserRole.cashier,
      createdAt: now,
    );

    test('toJson should serialize all fields', () {
      final json = model.toJson();
      expect(json['username'], 'testuser');
      expect(json['passwordHash'], 'hash123');
      expect(json['passwordSalt'], 'salt123');
      expect(json['mustChangePassword'], true);
      expect(json['role'], 1);
      expect(json['createdAt'], now.toIso8601String());
    });

    test('fromJson should deserialize correctly', () {
      final json = {
        'username': 'admin',
        'passwordHash': 'adminhash',
        'passwordSalt': 'adminsalt',
        'mustChangePassword': true,
        'role': 0,
        'createdAt': now.toIso8601String(),
      };
      final model = AppUserModel.fromJson(json);
      expect(model.username, 'admin');
      expect(model.passwordHash, 'adminhash');
      expect(model.passwordSalt, 'adminsalt');
      expect(model.mustChangePassword, true);
      expect(model.role, UserRole.admin);
      expect(model.createdAt, now);
    });

    test('fromJson should handle missing fields', () {
      final model = AppUserModel.fromJson({});
      expect(model.username, '');
      expect(model.passwordHash, '');
      expect(model.passwordSalt, isNotEmpty);
      expect(model.mustChangePassword, false);
      expect(model.role, UserRole.admin);
    });

    test('toEntity should produce equivalent UserEntity', () {
      final entity = model.toEntity();
      expect(entity.username, model.username);
      expect(entity.passwordHash, model.passwordHash);
      expect(entity.passwordSalt, model.passwordSalt);
      expect(entity.mustChangePassword, model.mustChangePassword);
      expect(entity.role, model.role);
      expect(entity.createdAt, model.createdAt);
    });

    test('toJson round-trip should preserve data', () {
      final json = model.toJson();
      final restored = AppUserModel.fromJson(json);
      expect(restored.username, model.username);
      expect(restored.passwordHash, model.passwordHash);
      expect(restored.passwordSalt, model.passwordSalt);
      expect(restored.mustChangePassword, model.mustChangePassword);
      expect(restored.role, model.role);
      expect(restored.createdAt, model.createdAt);
    });
  });
}
