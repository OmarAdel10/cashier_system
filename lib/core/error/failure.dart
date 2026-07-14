sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'Failure(message: $message)';
}

class DatabaseFailure extends Failure {
  final Object? cause;
  const DatabaseFailure(super.message, {this.cause});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DatabaseFailure && other.cause == cause && other.message == message;
  }

  @override
  int get hashCode => Object.hash(cause, message);

  @override
  String toString() => 'DatabaseFailure(message: $message, cause: $cause)';
}

class ValidationFailure extends Failure {
  final String field;
  final String reason;
  const ValidationFailure(super.message, {required this.field, required this.reason});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationFailure && other.field == field && other.reason == reason && other.message == message;
  }

  @override
  int get hashCode => Object.hash(field, reason, message);

  @override
  String toString() => 'ValidationFailure(message: $message, field: $field, reason: $reason)';
}

class ItemNotFoundFailure extends Failure {
  final String barcode;
  const ItemNotFoundFailure(super.message, {required this.barcode});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemNotFoundFailure && other.barcode == barcode && other.message == message;
  }

  @override
  int get hashCode => Object.hash(barcode, message);

  @override
  String toString() => 'ItemNotFoundFailure(message: $message, barcode: $barcode)';
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthenticationFailure && other.reason == reason && other.message == message;
  }

  @override
  int get hashCode => Object.hash(reason, message);

  @override
  String toString() => 'AuthenticationFailure(message: $message, reason: $reason)';
}

class ReceiptPersistenceFailure extends Failure {
  final Object? cause;
  const ReceiptPersistenceFailure(super.message, {this.cause});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptPersistenceFailure && other.cause == cause && other.message == message;
  }

  @override
  int get hashCode => Object.hash(cause, message);

  @override
  String toString() => 'ReceiptPersistenceFailure(message: $message, cause: $cause)';
}
