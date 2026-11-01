enum ZoneKind { dineIn, takeaway }

class ZoneEntity {
  final String id;
  final String name;
  final ZoneKind kind;

  const ZoneEntity({
    required this.id,
    required this.name,
    this.kind = ZoneKind.dineIn,
  });

  ZoneEntity copyWith({String? id, String? name, ZoneKind? kind}) {
    return ZoneEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(id, name, kind);
}
