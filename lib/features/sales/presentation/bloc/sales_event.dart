sealed class SalesEvent {
  const SalesEvent();
}

class LoadTodaySummary extends SalesEvent {
  const LoadTodaySummary({this.includeTaxInProfit = true});

  final bool includeTaxInProfit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadTodaySummary &&
          includeTaxInProfit == other.includeTaxInProfit;
  @override
  int get hashCode => includeTaxInProfit.hashCode;
}

class LoadMonth extends SalesEvent {
  final int year;
  final int month;
  final bool includeTaxInProfit;
  const LoadMonth({
    required this.year,
    required this.month,
    this.includeTaxInProfit = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadMonth &&
          year == other.year &&
          month == other.month &&
          includeTaxInProfit == other.includeTaxInProfit;
  @override
  int get hashCode => Object.hash(year, month, includeTaxInProfit);
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

class LoadSessionRecords extends SalesEvent {
  final int? limit;
  const LoadSessionRecords({this.limit});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadSessionRecords && limit == other.limit;
  @override
  int get hashCode => limit.hashCode;
}
