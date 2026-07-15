import '../../../../core/error/failure.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';

enum SalesStatus { initial, loading, ready, error }

class TodaySummary {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;

  const TodaySummary({
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodaySummary &&
          runtimeType == other.runtimeType &&
          totalPiastres == other.totalPiastres &&
          receiptCount == other.receiptCount &&
          itemsSold == other.itemsSold;

  @override
  int get hashCode => Object.hash(totalPiastres, receiptCount, itemsSold);

  @override
  String toString() =>
      'TodaySummary(totalPiastres: $totalPiastres, receiptCount: $receiptCount, itemsSold: $itemsSold)';
}

class MonthData {
  final int year;
  final int month;
  final int totalPiastres;
  final int receiptCount;
  final List<ReceiptEntity> receipts;

  const MonthData({
    required this.year,
    required this.month,
    required this.totalPiastres,
    required this.receiptCount,
    this.receipts = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthData &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          totalPiastres == other.totalPiastres &&
          receiptCount == other.receiptCount &&
          receipts == other.receipts;

  @override
  int get hashCode => Object.hash(year, month, totalPiastres, receiptCount, receipts);

  @override
  String toString() =>
      'MonthData(year: $year, month: $month, totalPiastres: $totalPiastres, receiptCount: $receiptCount, receipts: ${receipts.length})';
}

class SalesState {
  final SalesStatus status;
  final TodaySummary? todaySummary;
  final MonthData? monthData;
  final List<MonthData> months;
  final List<ReceiptEntity>? shiftReceipts;
  final Failure? failure;

  const SalesState({
    this.status = SalesStatus.initial,
    this.todaySummary,
    this.monthData,
    this.months = const [],
    this.shiftReceipts,
    this.failure,
  });

  SalesState copyWith({
    SalesStatus? status,
    TodaySummary? todaySummary,
    MonthData? monthData,
    List<MonthData>? months,
    List<ReceiptEntity>? shiftReceipts,
    Failure? failure,
    bool clearFailure = false,
    bool clearMonthData = false,
    bool clearTodaySummary = false,
    bool clearMonths = false,
    bool clearShiftReceipts = false,
  }) {
    return SalesState(
      status: status ?? this.status,
      todaySummary: clearTodaySummary ? null : (todaySummary ?? this.todaySummary),
      monthData: clearMonthData ? null : (monthData ?? this.monthData),
      months: clearMonths ? const [] : (months ?? this.months),
      shiftReceipts: clearShiftReceipts ? null : (shiftReceipts ?? this.shiftReceipts),
      failure: clearFailure ? null : (failure ?? this.failure),
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
          failure == other.failure;

  @override
  int get hashCode =>
      Object.hash(status, todaySummary, monthData, months, shiftReceipts, failure);

  @override
  String toString() =>
      'SalesState(status: $status, todaySummary: $todaySummary, monthData: $monthData, months: ${months.length}, shiftReceipts: ${shiftReceipts?.length}, failure: $failure)';
}
