import 'package:hive/hive.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

class AppUserModel extends UserEntity {
  const AppUserModel({
    required super.username,
    required super.passwordHash,
    required super.role,
    required super.createdAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      role: (json['role'] as int? ?? 0) == 0 ? UserRole.admin : UserRole.cashier,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'passwordHash': passwordHash,
    'role': role == UserRole.admin ? 0 : 1,
    'createdAt': createdAt.toIso8601String(),
  };

  UserEntity toEntity() => UserEntity(
    username: username,
    passwordHash: passwordHash,
    role: role,
    createdAt: createdAt,
  );
}

class AppUserModelAdapter extends TypeAdapter<AppUserModel> {
  @override
  final int typeId = 2;

  @override
  AppUserModel read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var i = 0, n = reader.readByte(); i < n; i++) {
      final k = reader.readByte();
      fields[k] = reader.read();
    }
    return AppUserModel(
      username: fields[0] as String? ?? '',
      passwordHash: fields[1] as String? ?? '',
      role: (fields[2] as int? ?? 0) == 0 ? UserRole.admin : UserRole.cashier,
      createdAt: fields[3] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, AppUserModel obj) {
    writer.writeByte(4);
    writer.writeByte(0); writer.write(obj.username);
    writer.writeByte(1); writer.write(obj.passwordHash);
    writer.writeByte(2); writer.write(obj.role == UserRole.admin ? 0 : 1);
    writer.writeByte(3); writer.write(obj.createdAt);
  }
}
