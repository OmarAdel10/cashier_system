import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import '../../helpers/fake_auth_repository.dart';

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
      bloc.add(const LoginRequested('admin', 'admin'));

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
}
