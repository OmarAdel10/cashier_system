sealed class Failure {
  final String message;
  const Failure(this.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ItemNotFoundFailure extends Failure {
  const ItemNotFoundFailure(super.message);
}

enum AuthFailureReason {
  invalidCredentials,
  userNotFound,
  duplicateUsername,
  weakPassword,
  wrongCurrentPassword,
  cannotDeleteSelf,
  unauthorized,
  invalidUsername,
}

class AuthenticationFailure extends Failure {
  final AuthFailureReason reason;
  const AuthenticationFailure(super.message, this.reason);
}
