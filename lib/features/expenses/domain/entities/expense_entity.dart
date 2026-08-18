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
    this.name = '',
  });

  final String id;
  final String shiftId;
  final String username;
  final List<ExpenseLineEntity> lines;
  final DateTime createdAt;
  final String name;

  int get totalPiastres =>
      lines.fold(0, (sum, line) => sum + line.quantity * line.costPiastres);

  String get orderNumber {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final shortId = id.length >= 5 ? id.substring(0, 5) : id;
    return 'EXP-${shortId.toUpperCase()}';
  }

  ExpenseEntity copyWith({
    String? id,
    String? shiftId,
    String? username,
    List<ExpenseLineEntity>? lines,
    DateTime? createdAt,
    String? name,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      username: username ?? this.username,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
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
          createdAt == other.createdAt &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, shiftId, username, lines, createdAt, name);

  @override
  String toString() =>
      'ExpenseEntity(id: $id, name: $name, shiftId: $shiftId, username: $username, ${lines.length} lines, createdAt: $createdAt)';
}
