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

// Export events
sealed class SalesExportEvent extends SalesEvent {
  const SalesExportEvent({
    required this.format,
    required this.exportDirectoryPath,
  });

  /// Target file format: `'csv'` or `'pdf'`.
  final String format;

  /// Unified export directory fetched from Settings.
  final String exportDirectoryPath;
}

class ExportByMonth extends SalesExportEvent {
  final int year;
  final int month;
  const ExportByMonth({
    required this.year,
    required this.month,
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportByMonth &&
          year == other.year &&
          month == other.month &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode => Object.hash(year, month, format, exportDirectoryPath);
}

class ExportByDay extends SalesExportEvent {
  final int year;
  final int month;
  final int day;
  const ExportByDay({
    required this.year,
    required this.month,
    required this.day,
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportByDay &&
          year == other.year &&
          month == other.month &&
          day == other.day &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode =>
      Object.hash(year, month, day, format, exportDirectoryPath);
}

class ExportAllMonths extends SalesExportEvent {
  const ExportAllMonths({
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportAllMonths &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode => Object.hash(format, exportDirectoryPath);
}

class ExportByYear extends SalesExportEvent {
  final int year;
  const ExportByYear({
    required this.year,
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportByYear &&
          year == other.year &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode => Object.hash(year, format, exportDirectoryPath);
}

class ExportMonthToMonth extends SalesExportEvent {
  final int startYear;
  final int startMonth;
  final int endYear;
  final int endMonth;
  const ExportMonthToMonth({
    required this.startYear,
    required this.startMonth,
    required this.endYear,
    required this.endMonth,
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportMonthToMonth &&
          startYear == other.startYear &&
          startMonth == other.startMonth &&
          endYear == other.endYear &&
          endMonth == other.endMonth &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode => Object.hash(
    startYear,
    startMonth,
    endYear,
    endMonth,
    format,
    exportDirectoryPath,
  );
}

class ExportDayToDay extends SalesExportEvent {
  final int startYear;
  final int startMonth;
  final int startDay;
  final int endYear;
  final int endMonth;
  final int endDay;
  const ExportDayToDay({
    required this.startYear,
    required this.startMonth,
    required this.startDay,
    required this.endYear,
    required this.endMonth,
    required this.endDay,
    required super.format,
    required super.exportDirectoryPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportDayToDay &&
          startYear == other.startYear &&
          startMonth == other.startMonth &&
          startDay == other.startDay &&
          endYear == other.endYear &&
          endMonth == other.endMonth &&
          endDay == other.endDay &&
          format == other.format &&
          exportDirectoryPath == other.exportDirectoryPath;
  @override
  int get hashCode => Object.hash(
    startYear,
    startMonth,
    startDay,
    endYear,
    endMonth,
    endDay,
    format,
    exportDirectoryPath,
  );
}
