class ShiftEntity {
  final String id;
  final String username;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int openingFloat;

  const ShiftEntity({
    required this.id,
    required this.username,
    required this.startedAt,
    this.endedAt,
    this.openingFloat = 0,
  });

  ShiftEntity copyWith({
    String? id,
    String? username,
    DateTime? startedAt,
    DateTime? endedAt,
    int? openingFloat,
  }) {
    return ShiftEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      openingFloat: openingFloat ?? this.openingFloat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          openingFloat == other.openingFloat;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      startedAt.hashCode ^
      endedAt.hashCode ^
      openingFloat.hashCode;
}
