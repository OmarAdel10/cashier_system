import '../../domain/entities/user_role.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class CheckAuth extends AuthEvent {
  const CheckAuth();
}

final class LoginRequested extends AuthEvent {
  final String username;
  final String password;
  const LoginRequested(this.username, this.password);
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

final class LoadUsers extends AuthEvent {
  const LoadUsers();
}

final class CreateUser extends AuthEvent {
  final String username;
  final String password;
  final UserRole role;
  const CreateUser(this.username, this.password, this.role);
}

final class ChangePassword extends AuthEvent {
  final String username;
  final String currentPassword;
  final String newPassword;
  const ChangePassword(this.username, this.currentPassword, this.newPassword);
}

final class DeleteUser extends AuthEvent {
  final String username;
  const DeleteUser(this.username);
}
