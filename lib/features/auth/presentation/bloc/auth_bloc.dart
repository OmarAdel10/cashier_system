import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _repository;
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  AuthBloc({required IAuthRepository repository})
      : _repository = repository,
        super(const AuthState()) {
    on<CheckAuth>(_onCheckAuth);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<LoadUsers>(_onLoadUsers);
    on<CreateUser>(_onCreateUser);
    on<ChangePassword>(_onChangePassword);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onCheckAuth(
      CheckAuth event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _repository.getAll();
      result.fold(
        (failure) => emit(state.copyWith(status: AuthStatus.unauthenticated, failure: failure)),
        (_) => emit(state.copyWith(status: AuthStatus.unauthenticated)),
      );
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        failure: DatabaseFailure('Unexpected error: $e'),
      ));
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    if (_failedAttempts >= 3 &&
        _lastFailedAttempt != null &&
        DateTime.now().difference(_lastFailedAttempt!) < Duration(seconds: _failedAttempts * 2)) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        failure: const AuthenticationFailure('Too many failed attempts. Try later.', AuthFailureReason.invalidCredentials),
      ));
      return;
    }
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    try {
      final result = await _repository.getByUsername(event.username);
      result.fold(
        (failure) {
          _failedAttempts++;
          _lastFailedAttempt = DateTime.now();
          emit(state.copyWith(
              status: AuthStatus.unauthenticated, failure: failure));
        },
        (user) {
          if (user == null) {
            _failedAttempts++;
            _lastFailedAttempt = DateTime.now();
            emit(state.copyWith(
              status: AuthStatus.unauthenticated,
              failure: const AuthenticationFailure('User not found', AuthFailureReason.userNotFound),
            ));
            return;
          }
          if (user.passwordHash != hashPassword(event.password, user.passwordSalt)) {
            _failedAttempts++;
            _lastFailedAttempt = DateTime.now();
            emit(state.copyWith(
              status: AuthStatus.unauthenticated,
              failure: const AuthenticationFailure('Invalid credentials', AuthFailureReason.invalidCredentials),
            ));
            return;
          }
          _failedAttempts = 0;
          _lastFailedAttempt = null;
          if (user.mustChangePassword) {
            emit(state.copyWith(
              status: AuthStatus.passwordChangeRequired,
              user: user,
              failure: const AuthenticationFailure('Password change required. Please change your password in Settings.', AuthFailureReason.weakPassword),
            ));
            return;
          }
          emit(state.copyWith(status: AuthStatus.authenticated, user: user));
        },
      );
    } catch (e) {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        failure: DatabaseFailure('Unexpected error: $e'),
      ));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onLoadUsers(
      LoadUsers event, Emitter<AuthState> emit) async {
    emit(state.copyWith(clearFailure: true));
    try {
      final result = await _repository.getAll();
      result.fold(
        (failure) => emit(state.copyWith(failure: failure)),
        (users) => emit(state.copyWith(users: users)),
      );
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }

  Future<void> _onCreateUser(
      CreateUser event, Emitter<AuthState> emit) async {
    emit(state.copyWith(clearFailure: true));
    if (state.user == null || state.user!.role != UserRole.admin) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Admin access required', AuthFailureReason.unauthorized),
      ));
      return;
    }
    if (!_usernameRegex.hasMatch(event.username)) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Invalid username (3-30 chars, letters/numbers/underscores)', AuthFailureReason.invalidUsername),
      ));
      return;
    }
    if (event.password.length < 8) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Password must be at least 8 characters', AuthFailureReason.weakPassword),
      ));
      return;
    }
    if (state.users.any((u) => u.username == event.username)) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Username already exists', AuthFailureReason.duplicateUsername),
      ));
      return;
    }
    final salt = generateSalt();
    final user = UserEntity(
      username: event.username,
      passwordHash: hashPassword(event.password, salt),
      passwordSalt: salt,
      role: event.role,
      createdAt: DateTime.now(),
    );
    try {
      final result = await _repository.save(user);
      result.fold(
        (failure) => emit(state.copyWith(failure: failure)),
        (_) => add(const LoadUsers()),
      );
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }

  Future<void> _onChangePassword(
      ChangePassword event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    if (state.user == null) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Not authenticated', AuthFailureReason.unauthorized),
      ));
      return;
    }
    if (event.username != state.user!.username &&
        state.user!.role != UserRole.admin) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Only admins can change other users\' passwords', AuthFailureReason.unauthorized),
      ));
      return;
    }
    if (event.newPassword.length < 8) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('New password must be at least 8 characters', AuthFailureReason.weakPassword),
      ));
      return;
    }
    final targetUser = event.username == state.user!.username
        ? state.user!
        : state.users.where((u) => u.username == event.username).firstOrNull;
    if (targetUser == null) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('User not found', AuthFailureReason.userNotFound),
      ));
      return;
    }
    if (event.username == state.user!.username) {
      if (state.user!.passwordHash != hashPassword(event.currentPassword, state.user!.passwordSalt)) {
        emit(state.copyWith(
          failure: const AuthenticationFailure('Wrong current password', AuthFailureReason.wrongCurrentPassword),
        ));
        return;
      }
    }
    final updated = targetUser.copyWith(
      passwordHash: hashPassword(event.newPassword, targetUser.passwordSalt),
      mustChangePassword: false,
    );
    try {
      final result = await _repository.save(updated);
      result.fold(
        (failure) => emit(state.copyWith(failure: failure)),
        (_) {
          if (event.username == state.user!.username) {
            emit(state.copyWith(status: AuthStatus.authenticated, user: updated));
          } else {
            add(const LoadUsers());
          }
        },
      );
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }

  Future<void> _onDeleteUser(
      DeleteUser event, Emitter<AuthState> emit) async {
    emit(state.copyWith(clearFailure: true));
    if (state.user == null || state.user!.role != UserRole.admin) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Admin access required', AuthFailureReason.unauthorized),
      ));
      return;
    }
    if (event.username == state.user?.username) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Cannot delete yourself', AuthFailureReason.cannotDeleteSelf),
      ));
      return;
    }
    try {
      final result = await _repository.delete(event.username);
      result.fold(
        (failure) => emit(state.copyWith(failure: failure)),
        (_) => add(const LoadUsers()),
      );
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }
}
