import 'dart:convert';
import 'dart:math';

import 'user_role.dart';

final _random = Random.secure();

class UserEntity {
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final bool mustChangePassword;
  final UserRole role;
  final DateTime createdAt;

  UserEntity({
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
    String? passwordSalt,
    this.mustChangePassword = false,
  }) : passwordSalt = (passwordSalt != null && passwordSalt.isNotEmpty)
           ? passwordSalt
           : _generateSalt();

  static String _generateSalt() =>
      base64Url.encode(List.generate(32, (_) => _random.nextInt(256)));

  UserEntity copyWith({
    String? username,
    String? passwordHash,
    String? passwordSalt,
    bool? mustChangePassword,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return UserEntity(
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          passwordHash == other.passwordHash &&
          passwordSalt == other.passwordSalt &&
          mustChangePassword == other.mustChangePassword &&
          role == other.role &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      username.hashCode ^
      passwordHash.hashCode ^
      passwordSalt.hashCode ^
      mustChangePassword.hashCode ^
      role.hashCode ^
      createdAt.hashCode;
}
