enum PaymentType {
  cash('cash'),
  instapay('instapay'),
  vodafoneCash('vodafoneCash'),
  visa('visa');

  const PaymentType(this.id);

  final String id;

  static const List<PaymentType> all = PaymentType.values;

  static PaymentType fromId(String id) {
    return PaymentType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => PaymentType.cash,
    );
  }

  static List<PaymentType> fromIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return PaymentType.values;
    final known = ids.map(fromId).toSet();
    return PaymentType.values.where(known.contains).toList();
  }
}
