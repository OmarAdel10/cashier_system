import '../../../../core/error/failure.dart';
import '../../../checkout/domain/entities/session_record_entity.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';

enum SalesStatus { initial, loading, ready, error }

class TodaySummary {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;
  final int profitPiastres;
  final int taxPiastres;
  final int unknownCostCount;

  const TodaySummary({
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
    this.profitPiastres = 0,
    this.taxPiastres = 0,
    this.unknownCostCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodaySummary &&
          runtimeType == other.runtimeType &&
          totalPiastres == other.totalPiastres &&
          receiptCount == other.receiptCount &&
          itemsSold == other.itemsSold &&
          profitPiastres == other.profitPiastres &&
          taxPiastres == other.taxPiastres &&
          unknownCostCount == other.unknownCostCount;

  @override
  int get hashCode => Object.hash(
    totalPiastres,
    receiptCount,
    itemsSold,
    profitPiastres,
    taxPiastres,
    unknownCostCount,
  );

  @override
  String toString() =>
      'TodaySummary(totalPiastres: $totalPiastres, receiptCount: $receiptCount, itemsSold: $itemsSold, profitPiastres: $profitPiastres, taxPiastres: $taxPiastres, unknownCostCount: $unknownCostCount)';
}

class ShiftGroup {
  final String shiftId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ReceiptEntity> receipts;

  const ShiftGroup({
    required this.shiftId,
    required this.startedAt,
    this.endedAt,
    this.receipts = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftGroup &&
          runtimeType == other.runtimeType &&
          shiftId == other.shiftId &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          receipts == other.receipts;

  @override
  int get hashCode => Object.hash(shiftId, startedAt, endedAt, receipts);
}

class CashierDayGroup {
  final String username;
  final List<ShiftGroup> shifts;

  const CashierDayGroup({required this.username, this.shifts = const []});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashierDayGroup &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          shifts == other.shifts;

  @override
  int get hashCode => Object.hash(username, shifts);
}

class DayGroup {
  final DateTime date;
  final List<CashierDayGroup> cashiers;
  final int expensesPiastres;

  const DayGroup({
    required this.date,
    this.cashiers = const [],
    this.expensesPiastres = 0,
  });

  DayGroup copyWith({
    DateTime? date,
    List<CashierDayGroup>? cashiers,
    int? expensesPiastres,
  }) => DayGroup(
    date: date ?? this.date,
    cashiers: cashiers ?? this.cashiers,
    expensesPiastres: expensesPiastres ?? this.expensesPiastres,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayGroup &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          cashiers == other.cashiers &&
          expensesPiastres == other.expensesPiastres;

  @override
  int get hashCode => Object.hash(date, cashiers, expensesPiastres);

  @override
  String toString() =>
      'DayGroup(date: $date, cashiers: $cashiers, expensesPiastres: $expensesPiastres)';
}

class MonthGroupedData {
  final int year;
  final int month;
  final int totalPiastres;
  final int receiptCount;
  final int expenseCount;
  final int itemsSold;
  final int profitPiastres;
  final int unknownCostCount;
  final List<DayGroup> days;

  const MonthGroupedData({
    required this.year,
    required this.month,
    this.totalPiastres = 0,
    this.receiptCount = 0,
    this.expenseCount = 0,
    this.itemsSold = 0,
    this.profitPiastres = 0,
    this.unknownCostCount = 0,
    this.days = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthGroupedData &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          totalPiastres == other.totalPiastres &&
          receiptCount == other.receiptCount &&
          expenseCount == other.expenseCount &&
          itemsSold == other.itemsSold &&
          profitPiastres == other.profitPiastres &&
          unknownCostCount == other.unknownCostCount &&
          days == other.days;

  @override
  int get hashCode => Object.hash(
    year,
    month,
    totalPiastres,
    receiptCount,
    expenseCount,
    itemsSold,
    profitPiastres,
    unknownCostCount,
    days,
  );

  @override
  String toString() =>
      'MonthGroupedData(year: $year, month: $month, totalPiastres: $totalPiastres, receiptCount: $receiptCount, expenseCount: $expenseCount, itemsSold: $itemsSold, profitPiastres: $profitPiastres, unknownCostCount: $unknownCostCount, days: ${days.length})';
}

enum ExportStatus { initial, loading, success, error }

class SalesState {
  final SalesStatus status;
  final TodaySummary? todaySummary;
  final MonthGroupedData? monthData;
  final List<MonthGroupedData> months;
  final List<ReceiptEntity>? shiftReceipts;
  final List<SessionRecordEntity>? sessionRecords;
  final Failure? failure;
  final ExportStatus? exportProgress;
  final String? exportFilePath;
  final String? exportFormat;
  final String? exportError;
  final String? exportDirectoryPath = '';
  final int todayExpensesPiastres;
  final int monthlyExpensesPiastres;
  final int shiftExpensesPiastres;

  const SalesState({
    this.status = SalesStatus.initial,
    this.todaySummary,
    this.monthData,
    this.months = const [],
    this.shiftReceipts,
    this.sessionRecords,
    this.failure,
    this.exportProgress,
    this.exportFilePath,
    this.exportFormat,
    this.exportError,
    this.todayExpensesPiastres = 0,
    this.monthlyExpensesPiastres = 0,
    this.shiftExpensesPiastres = 0,
  });

  SalesState copyWith({
    SalesStatus? status,
    TodaySummary? todaySummary,
    MonthGroupedData? monthData,
    List<MonthGroupedData>? months,
    List<ReceiptEntity>? shiftReceipts,
    List<SessionRecordEntity>? sessionRecords,
    Failure? failure,
    bool clearFailure = false,
    bool clearMonthData = false,
    bool clearTodaySummary = false,
    bool clearMonths = false,
    bool clearShiftReceipts = false,
    bool clearSessionRecords = false,
    ExportStatus? exportProgress,
    String? exportFilePath,
    String? exportFormat,
    String? exportError,
    bool clearExpenses = false,
    int? todayExpensesPiastres,
    int? monthlyExpensesPiastres,
    int? shiftExpensesPiastres,
  }) {
    return SalesState(
      status: status ?? this.status,
      todaySummary: clearTodaySummary
          ? null
          : (todaySummary ?? this.todaySummary),
      monthData: clearMonthData ? null : (monthData ?? this.monthData),
      months: clearMonths ? const [] : (months ?? this.months),
      shiftReceipts: clearShiftReceipts
          ? null
          : (shiftReceipts ?? this.shiftReceipts),
      sessionRecords: clearSessionRecords
          ? null
          : (sessionRecords ?? this.sessionRecords),
      failure: clearFailure ? null : (failure ?? this.failure),
      exportProgress: exportProgress ?? this.exportProgress,
      exportFilePath: exportFilePath ?? this.exportFilePath,
      exportFormat: exportFormat ?? this.exportFormat,
      exportError: exportError ?? this.exportError,
      todayExpensesPiastres: clearExpenses
          ? 0
          : (todayExpensesPiastres ?? this.todayExpensesPiastres),
      monthlyExpensesPiastres: clearExpenses
          ? 0
          : (monthlyExpensesPiastres ?? this.monthlyExpensesPiastres),
      shiftExpensesPiastres: clearExpenses
          ? 0
          : (shiftExpensesPiastres ?? this.shiftExpensesPiastres),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          todaySummary == other.todaySummary &&
          monthData == other.monthData &&
          months == other.months &&
          shiftReceipts == other.shiftReceipts &&
          sessionRecords == other.sessionRecords &&
          failure == other.failure &&
          todayExpensesPiastres == other.todayExpensesPiastres &&
          monthlyExpensesPiastres == other.monthlyExpensesPiastres &&
          shiftExpensesPiastres == other.shiftExpensesPiastres;

  @override
  int get hashCode => Object.hash(
    status,
    todaySummary,
    monthData,
    months,
    shiftReceipts,
    sessionRecords,
    failure,
    todayExpensesPiastres,
    monthlyExpensesPiastres,
    shiftExpensesPiastres,
  );

  @override
  String toString() =>
      'SalesState(status: $status, todaySummary: $todaySummary, monthData: $monthData, months: ${months.length}, shiftReceipts: ${shiftReceipts?.length}, sessionRecords: ${sessionRecords?.length}, failure: $failure, todayExpensesPiastres: $todayExpensesPiastres, monthlyExpensesPiastres: $monthlyExpensesPiastres, shiftExpensesPiastres: $shiftExpensesPiastres)';
}
