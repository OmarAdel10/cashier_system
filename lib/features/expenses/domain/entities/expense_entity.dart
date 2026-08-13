class ExpenseLineEntity {
  const ExpenseLineEntity({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.costPiastres,
  });

  final String barcode;
  final String name;
  final int quantity;
  final int costPiastres;

  ExpenseLineEntity copyWith({
    String? barcode,
    String? name,
    int? quantity,
    int? costPiastres,
  }) {
    return ExpenseLineEntity(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      costPiastres: costPiastres ?? this.costPiastres,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseLineEntity &&
          runtimeType == other.runtimeType &&
          barcode == other.barcode &&
          name == other.name &&
          quantity == other.quantity &&
          costPiastres == other.costPiastres;

  @override
  int get hashCode => Object.hash(barcode, name, quantity, costPiastres);

  @override
  String toString() =>
      'ExpenseLineEntity(barcode: $barcode, name: $name, quantity: $quantity, costPiastres: $costPiastres)';
}

class ExpenseEntity {
  const ExpenseEntity({
    required this.id,
    required this.shiftId,
    required this.username,
    required this.lines,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
  final String username;
  final List<ExpenseLineEntity> lines;
  final DateTime createdAt;

  int get totalPiastres =>
      lines.fold(0, (sum, line) => sum + line.quantity * line.costPiastres);

  ExpenseEntity copyWith({
    String? id,
    String? shiftId,
    String? username,
    List<ExpenseLineEntity>? lines,
    DateTime? createdAt,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      username: username ?? this.username,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shiftId == other.shiftId &&
          username == other.username &&
          lines == other.lines &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, shiftId, username, lines, createdAt);

  @override
  String toString() =>
      'ExpenseEntity(id: $id, shiftId: $shiftId, username: $username, ${lines.length} lines, createdAt: $createdAt)';
}
