import 'user_role.dart';

class UserEntity {
  final String username;
  final String passwordHash;
  final UserRole role;
  final DateTime createdAt;

  const UserEntity({
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
  });

  UserEntity copyWith({
    String? username,
    String? passwordHash,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return UserEntity(
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
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
          role == other.role &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      username.hashCode ^ passwordHash.hashCode ^ role.hashCode ^ createdAt.hashCode;
}
