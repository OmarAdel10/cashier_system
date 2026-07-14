sealed class SalesEvent {
  const SalesEvent();
}

class LoadTodaySummary extends SalesEvent {
  const LoadTodaySummary();

  @override
  bool operator ==(Object other) => identical(this, other) || other is LoadTodaySummary;
  @override
  int get hashCode => 0;
}

class LoadMonth extends SalesEvent {
  final int year;
  final int month;
  const LoadMonth({required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadMonth && year == other.year && month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}

class LoadShiftReceipts extends SalesEvent {
  final String shiftId;
  const LoadShiftReceipts({required this.shiftId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadShiftReceipts && shiftId == other.shiftId;
  @override
  int get hashCode => shiftId.hashCode;
}
