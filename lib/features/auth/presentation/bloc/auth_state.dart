import '../../../../core/error/failure.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final List<UserEntity> users;
  final Failure? failure;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.users = const [],
    this.failure,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    List<UserEntity>? users,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      users: users ?? this.users,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
