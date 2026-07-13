import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/app_user_model.dart';

final _random = Random.secure();

String _generateSalt() => base64Url.encode(List.generate(16, (_) => _random.nextInt(256)));

String _hashPassword(String password, String salt) {
  final passwordBytes = utf8.encode(password);
  final saltBytes = utf8.encode(salt);
  const iterations = 100000;
  const keyLength = 32;
  final hmac = Hmac(sha256, passwordBytes);
  final block1 = _pbkdf2Block(hmac, saltBytes, 1, iterations);
  final block2 = _pbkdf2Block(hmac, saltBytes, 2, iterations);
  final result = [...block1, ...block2];
  return base64.encode(result.sublist(0, keyLength));
}

List<int> _pbkdf2Block(Hmac hmac, List<int> salt, int blockIndex, int iterations) {
  final block = [...salt, (blockIndex >> 24) & 0xff, (blockIndex >> 16) & 0xff, (blockIndex >> 8) & 0xff, blockIndex & 0xff];
  var u = hmac.convert(block).bytes;
  var t = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}

List<UserEntity> _seedUsers() {
  final now = DateTime.now();
  return [
    final adminSalt = _generateSalt();
    final cashier1Salt = _generateSalt();
    final cashier2Salt = _generateSalt();
    return [
      UserEntity(
        username: 'admin',
        passwordHash: _hashPassword('admin', adminSalt),
        passwordSalt: adminSalt,
        mustChangePassword: true,
        role: UserRole.admin,
        createdAt: now,
      ),
      UserEntity(
        username: 'cashier1',
        passwordHash: _hashPassword('cashier1', cashier1Salt),
        passwordSalt: cashier1Salt,
        mustChangePassword: true,
        role: UserRole.cashier,
        createdAt: now,
      ),
      UserEntity(
        username: 'cashier2',
        passwordHash: _hashPassword('cashier2', cashier2Salt),
        passwordSalt: cashier2Salt,
        mustChangePassword: true,
        role: UserRole.cashier,
        createdAt: now,
      ),
    ];
  ];
}

class AuthRepositoryImpl implements IAuthRepository {
  final Box<AppUserModel> _box;

  AuthRepositoryImpl({required Box<AppUserModel> box}) : _box = box;

  Future<bool> get _hasSeeded async => _box.get('__seeded__') != null;

  Future<void> _ensureSeeded() async {
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
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async {
    try {
      await _ensureSeeded();
      final users = <UserEntity>[];
      for (final key in _box.keys) {
        if (key == '__seeded__') continue;
        final model = _box.get(key);
        if (model != null) users.add(model.toEntity());
      }
      return Right(users);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load users: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async {
    try {
      final model = _box.get(username);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to get user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> save(UserEntity user) async {
    try {
      final salt = user.passwordSalt.isEmpty ? _generateSalt() : user.passwordSalt;
      final model = AppUserModel(
        username: user.username,
        passwordHash: user.passwordHash,
        passwordSalt: salt,
        role: user.role,
        createdAt: user.createdAt,
      );
      await _box.put(user.username, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String username) async {
    try {
      await _box.delete(username);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete user: $e'));
    }
  }
}
