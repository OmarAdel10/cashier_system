import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audit/audit_event.dart';
import '../../../../core/audit/audit_service.dart';
import '../../../../core/crypto/password_hasher.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/i_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _repository;
  final AuditService? _auditService;
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  AuthBloc({required IAuthRepository repository, AuditService? auditService})
    : _repository = repository,
      _auditService = auditService,
      super(const AuthState()) {
    on<CheckAuth>(_onCheckAuth);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<LoadUsers>(_onLoadUsers);
    on<CreateUser>(_onCreateUser);
    on<ChangePassword>(_onChangePassword);
    on<DeleteUser>(_onDeleteUser);
    on<CompleteAdminSetup>(_onCompleteAdminSetup);
    on<RetrySetup>(_onRetrySetup);
  }

  Future<void> _onCheckAuth(CheckAuth event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _repository.getAll();
      await result.fold(
        (failure) async => emit(
          state.copyWith(status: AuthStatus.unauthenticated, failure: failure),
        ),
        (_) async {
          final setupResult = await _repository.isSetupCompleted();
          setupResult.fold(
            (failure) => emit(
              state.copyWith(
                status: AuthStatus.unauthenticated,
                failure: failure,
              ),
            ),
            (completed) {
              if (!completed) {
                emit(state.copyWith(status: AuthStatus.setupRequired));
              } else {
                emit(state.copyWith(status: AuthStatus.unauthenticated));
              }
            },
          );
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: DatabaseFailure('Unexpected error: $e'),
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_failedAttempts >= 3 && _lastFailedAttempt != null) {
      final cooldown = Duration(
        seconds: min(30 * (1 << (_failedAttempts - 3)), 3600),
      );
      if (DateTime.now().difference(_lastFailedAttempt!) < cooldown) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            failure: const AuthenticationFailure(
              'Too many failed attempts. Try later.',
              AuthFailureReason.invalidCredentials,
            ),
          ),
        );
        return;
      }
    }
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    try {
      final result = await _repository.getByUsername(event.username);
      result.fold(
        (failure) {
          _failedAttempts++;
          _lastFailedAttempt = DateTime.now();
          emit(
            state.copyWith(
              status: AuthStatus.unauthenticated,
              failure: failure,
            ),
          );
        },
        (user) {
          if (user == null) {
            _failedAttempts++;
            _lastFailedAttempt = DateTime.now();
            _auditService?.log(
              AuditEventType.loginFailed,
              username: event.username,
              details: 'User not found',
              success: false,
            );
            emit(
              state.copyWith(
                status: AuthStatus.unauthenticated,
                failure: const AuthenticationFailure(
                  'User not found',
                  AuthFailureReason.userNotFound,
                ),
              ),
            );
            return;
          }
          if (user.passwordHash !=
              hashPassword(event.password, user.passwordSalt)) {
            _failedAttempts++;
            _lastFailedAttempt = DateTime.now();
            _auditService?.log(
              AuditEventType.loginFailed,
              username: event.username,
              details: 'Invalid password',
              success: false,
            );
            emit(
              state.copyWith(
                status: AuthStatus.unauthenticated,
                failure: const AuthenticationFailure(
                  'Invalid credentials',
                  AuthFailureReason.invalidCredentials,
                ),
              ),
            );
            return;
          }
          _failedAttempts = 0;
          _lastFailedAttempt = null;
          if (user.mustChangePassword) {
            emit(
              state.copyWith(
                status: AuthStatus.passwordChangeRequired,
                user: user,
                failure: const AuthenticationFailure(
                  'Password change required. Please change your password in Settings.',
                  AuthFailureReason.weakPassword,
                ),
              ),
            );
            return;
          }
          _auditService?.log(
            AuditEventType.login,
            username: user.username,
            details: 'User logged in',
          );
          emit(state.copyWith(status: AuthStatus.authenticated, user: user));
        },
      );
    } catch (e) {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();
      _auditService?.log(
        AuditEventType.loginFailed,
        username: event.username,
        details: 'Login error: $e',
        success: false,
      );
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: DatabaseFailure('Unexpected error: $e'),
        ),
      );
    }
  }

  Future<void> _onCompleteAdminSetup(
    CompleteAdminSetup event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    if (event.password.length < 8) {
      emit(
        state.copyWith(
          status: AuthStatus.setupRequired,
          failure: const AuthenticationFailure(
            'Password must be at least 8 characters',
            AuthFailureReason.weakPassword,
          ),
        ),
      );
      return;
    }
    try {
      final result = await _repository.getByUsername('admin');
      await result.fold(
        (failure) async => emit(
          state.copyWith(status: AuthStatus.setupRequired, failure: failure),
        ),
        (user) async {
          if (user == null) {
            emit(
              state.copyWith(
                status: AuthStatus.setupRequired,
                failure: const AuthenticationFailure(
                  'Admin user not found',
                  AuthFailureReason.userNotFound,
                ),
              ),
            );
            return;
          }
          final salt = generateSalt();
          final updated = user.copyWith(
            passwordHash: hashPassword(event.password, salt),
            passwordSalt: salt,
            mustChangePassword: false,
          );
          final saveResult = await _repository.completeSetup(updated);
          saveResult.fold(
            (failure) => emit(
              state.copyWith(
                status: AuthStatus.setupRequired,
                failure: failure,
              ),
            ),
            (_) => emit(
              state.copyWith(status: AuthStatus.authenticated, user: updated),
            ),
          );
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.setupRequired,
          failure: DatabaseFailure('Unexpected error: $e'),
        ),
      );
    }
  }

  Future<void> _onRetrySetup(RetrySetup event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    try {
      final users = await _repository.getAll();
      users.fold(
        (failure) => emit(
          state.copyWith(status: AuthStatus.setupRequired, failure: failure),
        ),
        (_) => emit(state.copyWith(status: AuthStatus.setupRequired)),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.setupRequired,
          failure: DatabaseFailure('Unexpected error: $e'),
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _auditService?.log(
      AuditEventType.logout,
      username: state.user?.username,
      details: 'User logged out',
    );
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<AuthState> emit) async {
    emit(state.copyWith(clearFailure: true));
    try {
      final result = await _repository.getAll();
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: state.user != null
                ? AuthStatus.authenticated
                : AuthStatus.unauthenticated,
            failure: failure,
          ),
        ),
        (users) => emit(
          state.copyWith(
            status: state.user != null
                ? AuthStatus.authenticated
                : AuthStatus.unauthenticated,
            users: users,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: state.user != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          failure: DatabaseFailure('Unexpected error: $e'),
        ),
      );
    }
  }

  Future<void> _onCreateUser(CreateUser event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    if (state.user == null || state.user!.role != UserRole.admin) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Admin access required',
            AuthFailureReason.unauthorized,
          ),
        ),
      );
      return;
    }
    if (!_usernameRegex.hasMatch(event.username)) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Invalid username (3-30 chars, letters/numbers/underscores)',
            AuthFailureReason.invalidUsername,
          ),
        ),
      );
      return;
    }
    if (event.password.length < 8) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Password must be at least 8 characters',
            AuthFailureReason.weakPassword,
          ),
        ),
      );
      return;
    }
    if (state.users.any((u) => u.username == event.username)) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Username already exists',
            AuthFailureReason.duplicateUsername,
          ),
        ),
      );
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
      result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
        _auditService?.log(
          AuditEventType.userCreated,
          username: state.user?.username,
          details: 'Created user: ${event.username}',
        );
        add(const LoadUsers());
      });
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }

  Future<void> _onChangePassword(
    ChangePassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    if (state.user == null) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Not authenticated',
            AuthFailureReason.unauthorized,
          ),
        ),
      );
      return;
    }
    if (event.username != state.user!.username &&
        state.user!.role != UserRole.admin) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Only admins can change other users\' passwords',
            AuthFailureReason.unauthorized,
          ),
        ),
      );
      return;
    }
    if (event.newPassword.length < 8) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'New password must be at least 8 characters',
            AuthFailureReason.weakPassword,
          ),
        ),
      );
      return;
    }
    final targetUser = event.username == state.user!.username
        ? state.user!
        : state.users.where((u) => u.username == event.username).firstOrNull;
    if (targetUser == null) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'User not found',
            AuthFailureReason.userNotFound,
          ),
        ),
      );
      return;
    }
    if (event.username == state.user!.username) {
      if (state.user!.passwordHash !=
          hashPassword(event.currentPassword, state.user!.passwordSalt)) {
        emit(
          state.copyWith(
            failure: const AuthenticationFailure(
              'Wrong current password',
              AuthFailureReason.wrongCurrentPassword,
            ),
          ),
        );
        return;
      }
    }
    final newSalt = generateSalt();
    final updated = targetUser.copyWith(
      passwordHash: hashPassword(event.newPassword, newSalt),
      passwordSalt: newSalt,
      mustChangePassword: false,
    );
    try {
      final result = await _repository.save(updated);
      result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
        if (event.username == state.user!.username) {
          _auditService?.log(
            AuditEventType.passwordChanged,
            username: event.username,
            details: 'Password changed',
          );
          emit(state.copyWith(status: AuthStatus.authenticated, user: updated));
        } else {
          _auditService?.log(
            AuditEventType.passwordChanged,
            username: state.user?.username,
            details: 'Admin changed password for: ${event.username}',
          );
          add(const LoadUsers());
        }
      });
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<AuthState> emit) async {
    emit(state.copyWith(clearFailure: true));
    if (state.user == null || state.user!.role != UserRole.admin) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Admin access required',
            AuthFailureReason.unauthorized,
          ),
        ),
      );
      return;
    }
    if (event.username == state.user?.username) {
      emit(
        state.copyWith(
          failure: const AuthenticationFailure(
            'Cannot delete yourself',
            AuthFailureReason.cannotDeleteSelf,
          ),
        ),
      );
      return;
    }
    try {
      final result = await _repository.delete(event.username);
      result.fold((failure) => emit(state.copyWith(failure: failure)), (_) {
        _auditService?.log(
          AuditEventType.userDeleted,
          username: state.user?.username,
          details: 'Deleted user: ${event.username}',
        );
        add(const LoadUsers());
      });
    } catch (e) {
      emit(state.copyWith(failure: DatabaseFailure('Unexpected error: $e')));
    }
  }
}
