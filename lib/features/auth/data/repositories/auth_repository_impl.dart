import 'dart:math' as dartmath;

import 'package:hive/hive.dart';

import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/app_user_model.dart';

String _randomPassword() {
  final random = dartmath.Random.secure();
  final chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
}

List<UserEntity> _seedUsers() {
  final now = DateTime.now();
  final adminSalt = generateSalt();
  final cashier1Salt = generateSalt();
  final cashier2Salt = generateSalt();
  final adminPw = _randomPassword();
  final cashier1Pw = _randomPassword();
  final cashier2Pw = _randomPassword();
  return [
    UserEntity(
      username: 'admin',
      passwordHash: hashPassword(adminPw, adminSalt),
      passwordSalt: adminSalt,
      mustChangePassword: true,
      role: UserRole.admin,
      createdAt: now,
    ),
    UserEntity(
      username: 'cashier1',
      passwordHash: hashPassword(cashier1Pw, cashier1Salt),
      passwordSalt: cashier1Salt,
      mustChangePassword: true,
      role: UserRole.cashier,
      createdAt: now,
    ),
    UserEntity(
      username: 'cashier2',
      passwordHash: hashPassword(cashier2Pw, cashier2Salt),
      passwordSalt: cashier2Salt,
      mustChangePassword: true,
      role: UserRole.cashier,
      createdAt: now,
    ),
  ];
}

class AuthRepositoryImpl implements IAuthRepository {
  final Box<AppUserModel> _box;

  AuthRepositoryImpl({required Box<AppUserModel> box}) : _box = box;

  Future<bool> get _hasSeeded async => _box.get('__seeded__') != null;

  Future<void> _ensureSeeded() async {
    try {
      if (await _hasSeeded) return;
      for (final user in _seedUsers()) {
        final model = AppUserModel(
          username: user.username,
          passwordHash: user.passwordHash,
          passwordSalt: user.passwordSalt,
          mustChangePassword: user.mustChangePassword,
          role: user.role,
          createdAt: user.createdAt,
        );
        await _box.put(user.username, model);
      }
      await _box.put('__seeded__', AppUserModel(
        username: '__seeded__',
        passwordHash: '',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      throw DatabaseFailure('Failed to seed users', cause: e);
    }
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async {
    try {
      await _ensureSeeded();
      final users = <UserEntity>[];
      for (final key in _box.keys) {
        if (key == '__seeded__') continue;
        if (key == '__setup_completed__') continue;
        final model = _box.get(key);
        if (model != null) users.add(model.toEntity());
      }
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load users', cause: e));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async {
    try {
      final model = _box.get(username);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get user', cause: e));
    }
  }

  @override
  Future<Either<Failure, void>> save(UserEntity user) async {
    try {
      final salt = user.passwordSalt.isEmpty ? generateSalt() : user.passwordSalt;
      final model = AppUserModel(
        username: user.username,
        passwordHash: user.passwordHash,
        passwordSalt: salt,
        mustChangePassword: user.mustChangePassword,
        role: user.role,
        createdAt: user.createdAt,
      );
      await _box.put(user.username, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save user', cause: e));
    }
  }

  AppUserModel _markerModel(String key) => AppUserModel(
    username: key,
    passwordHash: '',
    role: UserRole.admin,
    createdAt: DateTime.now(),
  );

  @override
  Future<Either<Failure, void>> delete(String username) async {
    try {
      await _box.delete(username);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete user', cause: e));
    }
  }

  @override
  Future<Either<Failure, bool>> isSetupCompleted() async {
    try {
      final seeded = _box.get('__seeded__') != null;
      final completed = _box.get('__setup_completed__') != null;
      if (seeded && !completed) {
        return const Right(false);
      }
      return Right(completed);
    } catch (e) {
      return Left(DatabaseFailure('Failed to check setup status', cause: e));
    }
  }

  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async {
    try {
      final model = AppUserModel(
        username: admin.username,
        passwordHash: admin.passwordHash,
        passwordSalt: admin.passwordSalt,
        mustChangePassword: admin.mustChangePassword,
        role: admin.role,
        createdAt: admin.createdAt,
      );
      await _box.put(admin.username, model);
      await _box.put('__setup_completed__', _markerModel('__setup_completed__'));
      await _box.flush();
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to complete setup', cause: e));
    }
  }

  @override
  Future<Either<Failure, void>> retrySeeding() async {
    try {
      final seeded = _box.get('__seeded__') != null;
      if (seeded) {
        final admin = _box.get('admin');
        if (admin == null) {
          final now = DateTime.now();
          final salt = generateSalt();
          final adminUser = UserEntity(
            username: 'admin',
            passwordHash: hashPassword('admin', salt),
            passwordSalt: salt,
            mustChangePassword: true,
            role: UserRole.admin,
            createdAt: now,
          );
          await _box.put('admin', AppUserModel(
            username: adminUser.username,
            passwordHash: adminUser.passwordHash,
            passwordSalt: adminUser.passwordSalt,
            mustChangePassword: adminUser.mustChangePassword,
            role: adminUser.role,
            createdAt: adminUser.createdAt,
          ));
        }
      } else {
        await _ensureSeeded();
      }
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to retry seeding'));
    }
  }
}