import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';

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

class FakeAuthRepository implements IAuthRepository {
  final _users = <String, UserEntity>{};

  FakeAuthRepository() {
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    _users['admin'] = UserEntity(
      username: 'admin',
      passwordHash: _hashPassword('admin', 'test_salt'),
      passwordSalt: 'test_salt',
      mustChangePassword: true,
      role: UserRole.admin,
      createdAt: now,
    );
    _users['cashier1'] = UserEntity(
      username: 'cashier1',
      passwordHash: _hashPassword('cashier1', 'test_salt'),
      passwordSalt: 'test_salt',
      mustChangePassword: false,
      role: UserRole.cashier,
      createdAt: now,
    );
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async =>
      Right(_users.values.toList());

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async =>
      Right(_users[username]);

  @override
  Future<Either<Failure, void>> save(UserEntity user) async {
    _users[user.username] = user;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> delete(String username) async {
    _users.remove(username);
    return const Right(null);
  }
}
