import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/app_user_model.dart';

List<UserEntity> _seedUsers() {
  final now = DateTime.now();
  String hash(String pw) => sha256.convert(utf8.encode(pw)).toString();
  return [
    UserEntity(username: 'admin', passwordHash: hash('admin'), role: UserRole.admin, createdAt: now),
    UserEntity(username: 'cashier1', passwordHash: hash('cashier1'), role: UserRole.cashier, createdAt: now),
    UserEntity(username: 'cashier2', passwordHash: hash('cashier2'), role: UserRole.cashier, createdAt: now),
  ];
}

class AuthRepositoryImpl implements IAuthRepository {
  final Box<AppUserModel> _box;

  AuthRepositoryImpl({required Box<AppUserModel> box}) : _box = box;

  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async {
    try {
      if (_box.isEmpty) {
        for (final user in _seedUsers()) {
          final model = AppUserModel(
            username: user.username,
            passwordHash: user.passwordHash,
            role: user.role,
            createdAt: user.createdAt,
          );
          await _box.put(user.username, model);
        }
      }
      final users = <UserEntity>[];
      for (final key in _box.keys) {
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
      final model = AppUserModel(
        username: user.username,
        passwordHash: user.passwordHash,
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
