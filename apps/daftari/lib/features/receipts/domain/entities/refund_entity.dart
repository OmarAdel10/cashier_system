enum RefundType { full, partial }

class RefundEntity {
  final String id;
  final String originalReceiptId;
  final DateTime refundDate;
  final int amountRestored;
  final RefundType type;

  const RefundEntity({
    required this.id,
    required this.originalReceiptId,
    required this.refundDate,
    required this.amountRestored,
    required this.type,
  });

  RefundEntity copyWith({
    String? id,
    String? originalReceiptId,
    DateTime? refundDate,
    int? amountRestored,
    RefundType? type,
  }) {
    return RefundEntity(
      id: id ?? this.id,
      originalReceiptId: originalReceiptId ?? this.originalReceiptId,
      refundDate: refundDate ?? this.refundDate,
      amountRestored: amountRestored ?? this.amountRestored,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefundEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          originalReceiptId == other.originalReceiptId &&
          amountRestored == other.amountRestored &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, originalReceiptId, amountRestored, type);

  @override
  String toString() =>
      'RefundEntity(id: $id, originalReceiptId: $originalReceiptId, amountRestored: $amountRestored, type: $type)';
}
