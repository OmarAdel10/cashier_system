import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import '../../helpers/fake_auth_repository.dart';

class FailingFakeAuthRepository implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, void>> save(UserEntity user) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, void>> delete(String username) async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, bool>> isSetupCompleted() async =>
      Left(DatabaseFailure('DB error'));

  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async =>
      Left(DatabaseFailure('DB error'));
}

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

void main() {
  late AuthBloc bloc;
  late FakeAuthRepository repository;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    repository = FakeAuthRepository();
    bloc = AuthBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have initial status with no user', () {
      expect(bloc.state.status, AuthStatus.initial);
      expect(bloc.state.user, isNull);
      expect(bloc.state.users, isEmpty);
      expect(bloc.state.failure, isNull);
    });
  });

  group('CheckAuth', () {
    test('should emit unauthenticated after loading', () async {
      bloc.add(const CheckAuth());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
        ]),
      );
    });
  });

  group('LoginRequested', () {
    test('should authenticate with valid credentials', () async {
      bloc.add(const LoginRequested('cashier1', 'cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.authenticated &&
              s.user?.username == 'admin' &&
              s.user?.mustChangePassword == false),
        ]),
      );
    });

    test('should require password change for default credentials', () async {
      bloc.add(const LoginRequested('admin', 'admin'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.passwordChangeRequired &&
              s.user?.username == 'admin'),
        ]),
      );
    });

    test('should reject with wrong password', () async {
      bloc.add(const LoginRequested('admin', 'wrong'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.unauthenticated &&
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.invalidCredentials),
        ]),
      );
    });

    test('should reject non-existent user', () async {
      bloc.add(const LoginRequested('nobody', 'pass'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.unauthenticated &&
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.userNotFound),
        ]),
      );
    });
  });

  group('LogoutRequested', () {
    test('should clear auth state', () async {
      bloc.add(const LogoutRequested());

      await expectLater(
        bloc.stream,
        emits(predicate<AuthState>((s) =>
            s.status == AuthStatus.unauthenticated && s.user == null)),
      );
    });
  });

  group('LoadUsers', () {
    test('should load users from repository', () async {
      bloc.add(const LoadUsers());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.users.length == 2 &&
              s.users.any((u) => u.username == 'admin') &&
              s.users.any((u) => u.username == 'cashier1')),
        ]),
      );
    });
  });

  group('CreateUser', () {
    test('should create user when admin', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const CreateUser('newuser', 'password123', UserRole.cashier));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.users.any((u) => u.username == 'newuser')),
        ]),
      );
    });

    test('should reject when not admin', () async {
      bloc.add(const LoginRequested('cashier1', 'cashier1'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const CreateUser('newuser', 'password123', UserRole.cashier));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.unauthorized),
        ]),
      );
    });

    test('should reject invalid username', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const CreateUser('ab', 'password123', UserRole.cashier));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.invalidUsername),
        ]),
      );
    });

    test('should reject weak password', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const CreateUser('validuser', 'short', UserRole.cashier));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.weakPassword),
        ]),
      );
    });
  });

  group('ChangePassword', () {
    test('should change own password', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const ChangePassword('admin', 'admin', 'newpass123'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.authenticated &&
              s.user?.username == 'admin'),
        ]),
      );
    });

    test('should reject weak new password', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const ChangePassword('admin', 'admin', 'short'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.weakPassword),
        ]),
      );
    });

    test('should reject when not authenticated', () async {
      bloc.add(const ChangePassword('admin', 'admin', 'newpass123'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.unauthorized),
        ]),
      );
    });
  });

  group('DeleteUser', () {
    test('should delete user when admin', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const DeleteUser('cashier1'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.users.length == 1 && s.users.first.username == 'admin'),
        ]),
      );
    });

    test('should reject when not admin', () async {
      bloc.add(const LoginRequested('cashier1', 'cashier1'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const DeleteUser('admin'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.unauthorized),
        ]),
      );
    });

    test('should reject self-deletion', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const DeleteUser('admin'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.cannotDeleteSelf),
        ]),
      );
    });
  });

  group('rate limiting', () {
    test('should rate limit after 3 failed attempts', () async {
      for (var i = 0; i < 3; i++) {
        bloc.add(const LoginRequested('admin', 'wrong'));
        await bloc.stream.first;
        await bloc.stream.first;
      }

      bloc.add(const LoginRequested('admin', 'wrong'));

      await expectLater(
        bloc.stream,
        emits(predicate<AuthState>((s) =>
            s.status == AuthStatus.unauthenticated &&
            (s.failure as AuthenticationFailure).reason ==
                AuthFailureReason.invalidCredentials &&
            s.failure!.message == 'Too many failed attempts. Try later.')),
      );
    });
  });

  group('CreateUser duplicate', () {
    test('should reject duplicate username', () async {
      bloc.add(const LoginRequested('admin', 'admin'));
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const LoadUsers());
      await bloc.stream.first;
      await bloc.stream.first;

      bloc.add(const CreateUser('admin', 'password123', UserRole.cashier));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.duplicateUsername),
        ]),
      );
    });
  });

  group('CheckAuth - first time setup', () {
    test('emits setupRequired when setup not completed', () async {
      repository.setSetupCompleted(false);
      bloc.add(const CheckAuth());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) => s.status == AuthStatus.setupRequired),
        ]),
      );
    });

    test('emits unauthenticated when setup completed', () async {
      repository.setSetupCompleted(true);
      bloc.add(const CheckAuth());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
        ]),
      );
    });
  });

  group('CompleteAdminSetup', () {
    test('emits loading then authenticated with valid password', () async {
      repository.setSetupCompleted(false);
      bloc.add(CompleteAdminSetup('validPass123'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.authenticated &&
              s.user?.username == 'admin'),
        ]),
      );
    });

    test('emits setupRequired with weak password', () async {
      bloc.add(CompleteAdminSetup('short'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.setupRequired &&
              s.failure is AuthenticationFailure &&
              (s.failure as AuthenticationFailure).reason == AuthFailureReason.weakPassword),
        ]),
      );
    });
  });

  group('repository failure', () {
    test('should handle LoadUsers failure gracefully', () async {
      final failingBloc = AuthBloc(repository: FailingFakeAuthRepository());
      HydratedBloc.storage = _MockStorage();

      failingBloc.add(const LoadUsers());

      await expectLater(
        failingBloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.failure == null),
          predicate<AuthState>((s) =>
              s.failure is DatabaseFailure &&
              s.failure!.message.contains('DB error')),
        ]),
      );

      failingBloc.close();
    });

    test('should handle CheckAuth failure gracefully', () async {
      final failingBloc = AuthBloc(repository: FailingFakeAuthRepository());
      HydratedBloc.storage = _MockStorage();

      failingBloc.add(const CheckAuth());

      await expectLater(
        failingBloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.unauthenticated &&
              s.failure is DatabaseFailure &&
              s.failure!.message.contains('DB error')),
        ]),
      );

      failingBloc.close();
    });

    test('should handle LoginRequested catch block gracefully', () async {
      final failBloc = AuthBloc(repository: FailingFakeAuthRepository());
      HydratedBloc.storage = _MockStorage();

      failBloc.add(const LoginRequested('admin', 'admin'));

      await expectLater(
        failBloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.loading),
          predicate<AuthState>((s) =>
              s.status == AuthStatus.unauthenticated &&
              s.failure is DatabaseFailure),
        ]),
      );

      failBloc.close();
    });
  });
}
