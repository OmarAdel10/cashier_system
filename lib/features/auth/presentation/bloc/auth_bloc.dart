import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IAuthRepository _repository;

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

  String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<void> _onCheckAuth(
      CheckAuth event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.getAll();
    result.fold(
      (failure) => emit(state.copyWith(status: AuthStatus.unauthenticated, failure: failure)),
      (_) => emit(state.copyWith(status: AuthStatus.unauthenticated)),
    );
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final result = await _repository.getByUsername(event.username);
    result.fold(
      (failure) => emit(state.copyWith(
          status: AuthStatus.unauthenticated, failure: failure)),
      (user) {
        if (user == null) {
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            failure: const AuthenticationFailure('User not found', AuthFailureReason.userNotFound),
          ));
          return;
        }
        if (user.passwordHash != _hash(event.password)) {
          emit(state.copyWith(
            status: AuthStatus.unauthenticated,
            failure: const AuthenticationFailure('Invalid credentials', AuthFailureReason.invalidCredentials),
          ));
          return;
        }
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      },
    );
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onLoadUsers(
      LoadUsers event, Emitter<AuthState> emit) async {
    final result = await _repository.getAll();
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (users) => emit(state.copyWith(users: users)),
    );
  }

  Future<void> _onCreateUser(
      CreateUser event, Emitter<AuthState> emit) async {
    if (event.password.length < 4) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Password must be at least 4 characters', AuthFailureReason.weakPassword),
      ));
      return;
    }
    final existing = await _repository.getByUsername(event.username);
    final hasExisting = existing.fold((_) => false, (u) => u != null);
    if (hasExisting) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Username already exists', AuthFailureReason.duplicateUsername),
      ));
      return;
    }
    final user = UserEntity(
      username: event.username,
      passwordHash: _hash(event.password),
      role: event.role,
      createdAt: DateTime.now(),
    );
    final result = await _repository.save(user);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => add(const LoadUsers()),
    );
  }

  Future<void> _onChangePassword(
      ChangePassword event, Emitter<AuthState> emit) async {
    if (event.newPassword.length < 4) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('New password must be at least 4 characters', AuthFailureReason.weakPassword),
      ));
      return;
    }
    if (state.user == null || state.user!.passwordHash != _hash(event.currentPassword)) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Wrong current password', AuthFailureReason.wrongCurrentPassword),
      ));
      return;
    }
    final updated = state.user!.copyWith(passwordHash: _hash(event.newPassword));
    final result = await _repository.save(updated);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(state.copyWith(user: updated)),
    );
  }

  Future<void> _onDeleteUser(
      DeleteUser event, Emitter<AuthState> emit) async {
    if (event.username == state.user?.username) {
      emit(state.copyWith(
        failure: const AuthenticationFailure('Cannot delete yourself', AuthFailureReason.cannotDeleteSelf),
      ));
      return;
    }
    final result = await _repository.delete(event.username);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => add(const LoadUsers()),
    );
  }
}
