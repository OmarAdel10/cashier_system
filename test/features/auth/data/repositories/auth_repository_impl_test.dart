import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/data/models/app_user_model.dart';
import 'package:cashier_system/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';

void main() {
  late Box<AppUserModel> box;
  late AuthRepositoryImpl repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppUserModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppUserModel>('test_auth_users');
    repository = AuthRepositoryImpl(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_auth_users');
  });

  group('getAll', () {
    test('should seed default users on first call', () async {
      final result = await repository.getAll();
      final users = result.fold(
        (failure) => throw failure,
        (list) => list,
      );
      expect(users.length, 3);
      expect(users.any((u) => u.username == 'admin'), isTrue);
      expect(users.any((u) => u.username == 'cashier1'), isTrue);
      expect(users.any((u) => u.username == 'cashier2'), isTrue);
      expect(users.every((u) => u.mustChangePassword), isTrue);
    });

    test('should not re-seed on subsequent calls', () async {
      await repository.getAll();
      await box.delete('cashier1');
      final result = await repository.getAll();
      final users = result.fold(
        (failure) => throw failure,
        (list) => list,
      );
      expect(users.any((u) => u.username == 'cashier1'), isFalse);
    });
  });

  group('getByUsername', () {
    test('should return existing user', () async {
      await repository.getAll();
      final result = await repository.getByUsername('admin');
      final user = result.fold(
        (failure) => throw failure,
        (u) => u,
      );
      expect(user, isNotNull);
      expect(user!.username, 'admin');
      expect(user.role, UserRole.admin);
    });

    test('should return null for non-existent user', () async {
      final result = await repository.getByUsername('nobody');
      final user = result.fold(
        (failure) => throw failure,
        (u) => u,
      );
      expect(user, isNull);
    });
  });

  group('save', () {
    test('should persist user and retrieve it', () async {
      final user = UserEntity(
        username: 'newuser',
        passwordHash: 'hash',
        passwordSalt: 'salt',
        role: UserRole.cashier,
        createdAt: DateTime.now(),
      );
      final saveResult = await repository.save(user);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getByUsername('newuser');
      final retrieved = result.fold(
        (failure) => throw failure,
        (u) => u,
      );
      expect(retrieved, isNotNull);
      expect(retrieved!.username, 'newuser');
      expect(retrieved.role, UserRole.cashier);
    });
  });

  group('delete', () {
    test('should remove user', () async {
      await repository.getAll();
      final deleteResult = await repository.delete('cashier1');
      expect(deleteResult, isA<Right<Failure, void>>());

      final result = await repository.getByUsername('cashier1');
      final user = result.fold(
        (failure) => throw failure,
        (u) => u,
      );
      expect(user, isNull);
    });
  });
}
