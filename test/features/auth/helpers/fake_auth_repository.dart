import 'package:cashier_system/core/crypto/password_hasher.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';

class FakeAuthRepository implements IAuthRepository {
  final _users = <String, UserEntity>{};
  bool _setupCompleted = true;

  FakeAuthRepository() {
    _seed();
  }

  void setSetupCompleted(bool value) => _setupCompleted = value;
  void removeAdmin() => _users.remove('admin');

  static final _testSalt = generateSalt();

  void _seed() {
    final now = DateTime.now();
    _users['admin'] = UserEntity(
      username: 'admin',
      passwordHash: hashPassword('admin', _testSalt),
      passwordSalt: _testSalt,
      mustChangePassword: true,
      role: UserRole.admin,
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

  @override
  Future<Either<Failure, bool>> isSetupCompleted() async =>
      Right(_setupCompleted);

  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async {
    _users[admin.username] = admin;
    _setupCompleted = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> retrySeeding() async => const Right(null);
}
