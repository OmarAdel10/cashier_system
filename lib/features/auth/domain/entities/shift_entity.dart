class ShiftEntity {
  final String id;
  final String username;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int openingFloat;
  final int orderCount;

  const ShiftEntity({
    required this.id,
    required this.username,
    required this.startedAt,
    this.endedAt,
    this.openingFloat = 0,
    this.orderCount = 1,
  });

  ShiftEntity copyWith({
    String? id,
    String? username,
    DateTime? startedAt,
    DateTime? endedAt,
    int? openingFloat,
    int? orderCount,
  }) {
    return ShiftEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      openingFloat: openingFloat ?? this.openingFloat,
      orderCount: orderCount ?? this.orderCount,
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
          openingFloat == other.openingFloat &&
          orderCount == other.orderCount;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      startedAt.hashCode ^
      endedAt.hashCode ^
      openingFloat.hashCode ^
      orderCount.hashCode;
}
