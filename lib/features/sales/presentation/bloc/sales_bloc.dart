import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/exports/csv_writer.dart';
import '../../../../core/exports/pdf_generator.dart';
import '../../../auth/domain/entities/shift_entity.dart';
import '../../../auth/domain/repositories/i_shifts_repository.dart';
import '../../../checkout/domain/repositories/i_session_record_repository.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/domain/entities/receipt_item.dart';
import '../../../receipts/domain/entities/receipt_status.dart';
import '../../../receipts/domain/repositories/receipts_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';
import '../../../../features/expenses/domain/repositories/i_expenses_repository.dart';
import '../../../expenses/domain/entities/expense_entity.dart';

const String kSalesExportNoDirectoryError = 'NO_EXPORT_DIRECTORY';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final IReceiptsRepository _receiptsRepo;
  final IShiftsRepository _shiftsRepo;
  final ISessionRecordRepository? _sessionRecordsRepo;
  final IExpensesRepository? _expensesRepo;

  SalesBloc({
    required IReceiptsRepository receiptsRepo,
    required IShiftsRepository shiftsRepo,
    ISessionRecordRepository? sessionRecordsRepo,
    IExpensesRepository? expensesRepo,
  }) : _receiptsRepo = receiptsRepo,
       _shiftsRepo = shiftsRepo,
       _sessionRecordsRepo = sessionRecordsRepo,
       _expensesRepo = expensesRepo,
       super(const SalesState()) {
    on<LoadTodaySummary>(_onLoadTodaySummary);
    on<LoadMonth>(_onLoadMonth);
    on<LoadShiftReceipts>(_onLoadShiftReceipts);
    on<LoadSessionRecords>(_onLoadSessionRecords);
    on<ExportByDay>(_onExportByDay);
    on<ExportByMonth>(_onExportByMonth);
    on<ExportByYear>(_onExportByYear);
    on<ExportAllMonths>(_onExportAllMonths);
    on<ExportMonthToMonth>(_onExportMonthToMonth);
    on<ExportDayToDay>(_onExportDayToDay);
  }

  Future<void> _onLoadTodaySummary(
    LoadTodaySummary event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    final today = DateTime.now();
    final result = await _receiptsRepo.getByDate(today);

    var todayExpensesPiastres = 0;
    if (_expensesRepo != null) {
      final expensesEither = await _expensesRepo.getByDate(today);
      todayExpensesPiastres = expensesEither.fold(
        (_) => 0,
        (list) => list.fold(0, (sum, e) => sum + e.totalPiastres),
      );
    }

    Failure? failure;
    List<ReceiptEntity>? receipts;
    result.fold((f) => failure = f, (r) => receipts = r);

    if (failure != null) {
      emit(state.copyWith(status: SalesStatus.error, failure: failure));
      return;
    }

    final activeReceipts = receipts!
        .where((r) => r.status != ReceiptStatus.returned)
        .toList();
    final totalPiastres = activeReceipts.fold<int>(
      0,
      (sum, r) => sum + r.totalPiastres,
    );
    final itemsSold = activeReceipts.fold<int>(
      0,
      (sum, r) => sum + r.items.fold<int>(0, (s, i) => s + i.quantity),
    );
    emit(
      state.copyWith(
        status: SalesStatus.ready,
        todaySummary: TodaySummary(
          totalPiastres: totalPiastres,
          receiptCount: activeReceipts.length,
          itemsSold: itemsSold,
          taxPiastres: activeReceipts.fold<int>(
            0,
            (sum, r) => sum + r.taxPiastres,
          ),
        ),
        todayExpensesPiastres: todayExpensesPiastres,
      ),
    );
  }

  Future<void> _onLoadMonth(LoadMonth event, Emitter<SalesState> emit) async {
    emit(
      state.copyWith(
        status: SalesStatus.loading,
        clearMonthData: true,
        clearFailure: true,
      ),
    );

    final results = await Future.wait([
      _receiptsRepo.getByMonth(event.year, event.month),
      _shiftsRepo.getByMonth(event.year, event.month),
    ]);

    final receiptResult = results[0] as Either<Failure, List<ReceiptEntity>>;
    final shiftResult = results[1] as Either<Failure, List<ShiftEntity>>;

    Either<Failure, void>? failure;
    List<ReceiptEntity>? receipts;

    receiptResult.fold((f) => failure = Left(f), (r) => receipts = r);

    List<ShiftEntity> shifts = [];
    shiftResult.fold((_) {
      /* non-fatal — orphan fallback handles missing shifts */
    }, (s) => shifts = s);

    if (failure != null) {
      failure!.fold(
        (f) => emit(state.copyWith(status: SalesStatus.error, failure: f)),
        (_) {},
      );
      return;
    }

    final shiftMap = {for (final s in shifts) s.id: s};
    final dayMap = <DateTime, List<ReceiptEntity>>{};

    for (final r in receipts!) {
      final day = DateTime(
        r.createdAt.year,
        r.createdAt.month,
        r.createdAt.day,
      );
      dayMap.putIfAbsent(day, () => []).add(r);
    }

    var monthlyExpensesPiastres = 0;
    var monthlyExpenseCount = 0;
    final dayExpensesMap = <DateTime, int>{};
    final expensesRepo = _expensesRepo;
    if (expensesRepo != null) {
      final expensesEither = await expensesRepo.getByMonth(
        event.year,
        event.month,
      );
      final expenses = expensesEither.fold(
        (_) => <ExpenseEntity>[],
        (list) => list,
      );
      for (final e in expenses) {
        final day = DateTime(
          e.createdAt.year,
          e.createdAt.month,
          e.createdAt.day,
        );
        dayExpensesMap.update(
          day,
          (v) => v + e.totalPiastres,
          ifAbsent: () => e.totalPiastres,
        );
        dayMap.putIfAbsent(day, () => []).add(_expenseToReceipt(e));
      }
      monthlyExpensesPiastres = expenses.fold(
        0,
        (sum, e) => sum + e.totalPiastres,
      );
      monthlyExpenseCount = expenses.length;
    }

    final sortedDays = dayMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final groupedDays = <DayGroup>[];

    for (final day in sortedDays) {
      final dayReceipts = dayMap[day]!;
      final cashierMap = <String, List<ReceiptEntity>>{};

      for (final r in dayReceipts) {
        cashierMap.putIfAbsent(r.username, () => []).add(r);
      }

      final sortedCashiers = cashierMap.keys.toList()..sort();
      final cashierGroups = <CashierDayGroup>[];

      for (final username in sortedCashiers) {
        final cashierReceipts = cashierMap[username]!;
        final shiftGroupMap = <String, List<ReceiptEntity>>{};

        for (final r in cashierReceipts) {
          shiftGroupMap.putIfAbsent(r.shiftId, () => []).add(r);
        }

        final sortedShiftIds = shiftGroupMap.keys.toList()
          ..sort((a, b) {
            final sa = shiftMap[a];
            final sb = shiftMap[b];
            if (sa == null && sb == null) return 0;
            if (sa == null) return 1;
            if (sb == null) return -1;
            return sb.startedAt.compareTo(sa.startedAt);
          });

        final shiftGroups = <ShiftGroup>[];
        for (final shiftId in sortedShiftIds) {
          final shiftReceipts = shiftGroupMap[shiftId]!
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final shift = shiftMap[shiftId];
          shiftGroups.add(
            ShiftGroup(
              shiftId: shiftId,
              startedAt: shift?.startedAt ?? shiftReceipts.first.createdAt,
              endedAt: shift?.endedAt,
              receipts: shiftReceipts,
            ),
          );
        }

        cashierGroups.add(
          CashierDayGroup(username: username, shifts: shiftGroups),
        );
      }

      groupedDays.add(
        DayGroup(
          date: day,
          cashiers: cashierGroups,
          expensesPiastres: dayExpensesMap[day] ?? 0,
        ),
      );
    }

    final activeReceipts = receipts!
        .where((r) => r.status != ReceiptStatus.returned)
        .toList();

    final totalPiastres = activeReceipts.fold<int>(
      0,
      (sum, r) => sum + r.totalPiastres,
    );
    final itemsSold = activeReceipts.fold<int>(
      0,
      (sum, r) => sum + r.items.fold<int>(0, (s, i) => s + i.quantity),
    );
    final monthGroupedData = MonthGroupedData(
      year: event.year,
      month: event.month,
      totalPiastres: totalPiastres,
      receiptCount: activeReceipts.length,
      expenseCount: monthlyExpenseCount,
      itemsSold: itemsSold,
      days: groupedDays,
    );

    var updatedMonths =
        [
          ...state.months.where(
            (m) => !(m.year == event.year && m.month == event.month),
          ),
          monthGroupedData,
        ]..sort(
          (a, b) => b.year != a.year
              ? b.year.compareTo(a.year)
              : b.month.compareTo(a.month),
        );
    if (updatedMonths.length > 12) {
      updatedMonths = updatedMonths.sublist(0, 12);
    }

    emit(
      state.copyWith(
        status: SalesStatus.ready,
        monthData: monthGroupedData,
        months: updatedMonths,
        monthlyExpensesPiastres: monthlyExpensesPiastres,
      ),
    );
  }

  Future<void> _onLoadShiftReceipts(
    LoadShiftReceipts event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    var shiftExpensesPiastres = 0;
    final expenseReceipts = <ReceiptEntity>[];
    final expensesRepo = _expensesRepo;
    if (expensesRepo != null) {
      final expensesEither = await expensesRepo.getByShift(event.shiftId);
      expensesEither.fold((_) {}, (list) {
        shiftExpensesPiastres = list.fold(0, (sum, e) => sum + e.totalPiastres);
        expenseReceipts.addAll(list.map(_expenseToReceipt));
      });
    }

    Failure? failure;
    final result = await _receiptsRepo.getByShift(event.shiftId);

    result.fold((l) => failure = l, (r) {
      final receipts = [...r, ...expenseReceipts]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(
        state.copyWith(
          status: SalesStatus.ready,
          shiftReceipts: receipts,
          shiftExpensesPiastres: shiftExpensesPiastres,
        ),
      );
    });

    if (failure != null) {
      emit(state.copyWith(status: SalesStatus.error, failure: failure));
    }
  }

  Future<void> _onLoadSessionRecords(
    LoadSessionRecords event,
    Emitter<SalesState> emit,
  ) async {
    final repo = _sessionRecordsRepo;
    if (repo == null) return;

    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    final result = await repo.getSessionRecords(limit: event.limit);

    result.fold(
      (failure) =>
          emit(state.copyWith(status: SalesStatus.error, failure: failure)),
      (records) {
        records.sort(
          (a, b) =>
              (b.endTime ??
                      b.startTime ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.endTime ??
                        a.startTime ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  ),
        );
        emit(
          state.copyWith(status: SalesStatus.ready, sessionRecords: records),
        );
      },
    );
  }

  Future<void> _onExportByMonth(
    ExportByMonth event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = await _receiptsForMonths(
      event.year,
      event.month,
      event.year,
      event.month,
    );
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName: 'sales_month_${event.year}_${_twoDigits(event.month)}',
      title: 'Sales Export - Month ${event.month}/${event.year}',
      receipts: receipts,
    );
  }

  Future<void> _onExportByDay(
    ExportByDay event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = await _receiptsForDays(
      DateTime(event.year, event.month, event.day),
      DateTime(event.year, event.month, event.day),
    );
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName:
          'sales_day_${event.year}_${_twoDigits(event.month)}_${_twoDigits(event.day)}',
      title: 'Sales Export - Day ${event.day}/${event.month}/${event.year}',
      receipts: receipts,
    );
  }

  Future<void> _onExportAllMonths(
    ExportAllMonths event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = <ReceiptEntity>[];
    final result = await _receiptsRepo.getAll();
    result.fold((_) {}, (list) => receipts.addAll(list));
    final expensesRepo = _expensesRepo;
    if (expensesRepo != null) {
      final expenses = await expensesRepo.getAll();
      expenses.fold(
        (_) {},
        (list) => receipts.addAll(list.map(_expenseToReceipt)),
      );
    }
    receipts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName: 'sales_all_months',
      title: 'Sales Export - All Months',
      receipts: receipts,
    );
  }

  Future<void> _onExportByYear(
    ExportByYear event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = await _receiptsForMonths(event.year, 1, event.year, 12);
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName: 'sales_year_${event.year}',
      title: 'Sales Export - Year ${event.year}',
      receipts: receipts,
    );
  }

  Future<void> _onExportMonthToMonth(
    ExportMonthToMonth event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = await _receiptsForMonths(
      event.startYear,
      event.startMonth,
      event.endYear,
      event.endMonth,
    );
    final start = '${event.startYear}_${_twoDigits(event.startMonth)}';
    final end = '${event.endYear}_${_twoDigits(event.endMonth)}';
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName: 'sales_monthtomonth_${start}_$end',
      title: 'Sales Export - Month $start to $end',
      receipts: receipts,
    );
  }

  Future<void> _onExportDayToDay(
    ExportDayToDay event,
    Emitter<SalesState> emit,
  ) async {
    final receipts = await _receiptsForDays(
      DateTime(event.startYear, event.startMonth, event.startDay),
      DateTime(event.endYear, event.endMonth, event.endDay),
    );
    final start =
        '${event.startYear}_${_twoDigits(event.startMonth)}_${_twoDigits(event.startDay)}';
    final end =
        '${event.endYear}_${_twoDigits(event.endMonth)}_${_twoDigits(event.endDay)}';
    await _writeExport(
      emit: emit,
      format: event.format,
      exportDirectoryPath: event.exportDirectoryPath,
      baseName: 'sales_daytoday_${start}_$end',
      title: 'Sales Export - Day $start to $end',
      receipts: receipts,
    );
  }

  /// Fetches receipts and expenses for every month in the inclusive range.
  Future<List<ReceiptEntity>> _receiptsForMonths(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
  ) async {
    final out = <ReceiptEntity>[];
    var year = startYear;
    var month = startMonth;
    var guard = 0;
    while (year < endYear || (year == endYear && month <= endMonth)) {
      if (guard++ > 1200) break;
      final result = await _receiptsRepo.getByMonth(year, month);
      result.fold((_) {}, (list) => out.addAll(list));
      final expensesRepo = _expensesRepo;
      if (expensesRepo != null) {
        final expenses = await expensesRepo.getByMonth(year, month);
        expenses.fold(
          (_) {},
          (list) => out.addAll(list.map(_expenseToReceipt)),
        );
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  /// Fetches receipts and expenses for every day in the inclusive range.
  Future<List<ReceiptEntity>> _receiptsForDays(
    DateTime from,
    DateTime to,
  ) async {
    final out = <ReceiptEntity>[];
    var day = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    var guard = 0;
    while (!day.isAfter(end)) {
      if (guard++ > 37000) break;
      final result = await _receiptsRepo.getByDate(day);
      result.fold((_) {}, (list) => out.addAll(list));
      final expensesRepo = _expensesRepo;
      if (expensesRepo != null) {
        final expenses = await expensesRepo.getByDate(day);
        expenses.fold(
          (_) {},
          (list) => out.addAll(list.map(_expenseToReceipt)),
        );
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  /// Writes the export file (CSV or PDF) and emits the outcome.
  Future<void> _writeExport({
    required Emitter<SalesState> emit,
    required String format,
    required String exportDirectoryPath,
    required String baseName,
    required String title,
    required List<ReceiptEntity> receipts,
  }) async {
    emit(
      state.copyWith(exportProgress: ExportStatus.loading, clearExport: true),
    );
    try {
      if (exportDirectoryPath.trim().isEmpty) {
        emit(
          state.copyWith(
            exportProgress: ExportStatus.error,
            exportError: kSalesExportNoDirectoryError,
          ),
        );
        return;
      }
      final dir = Directory(exportDirectoryPath);
      await dir.create(recursive: true);
      final isCsv = format == 'csv';
      final path = '${dir.path}/$baseName.${isCsv ? 'csv' : 'pdf'}';
      if (isCsv) {
        await writeCsvRows(_buildCsvRows(receipts), path);
      } else {
        final pdfBytes = await generateTablePdf(
          _buildCsvRows(receipts),
          title: title,
        );
        await File(path).writeAsBytes(pdfBytes);
      }
      emit(
        state.copyWith(
          exportProgress: ExportStatus.success,
          exportFilePath: path,
          exportFormat: format,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          exportProgress: ExportStatus.error,
          exportError: e.toString(),
        ),
      );
    }
  }

  ReceiptEntity _expenseToReceipt(ExpenseEntity expense) {
    return ReceiptEntity(
      id: expense.id,
      shiftId: expense.shiftId,
      orderNumber: expense.orderNumber,
      items: [
        for (final line in expense.lines)
          ReceiptItem(
            name: line.name,
            barcode: line.barcode,
            quantity: line.quantity,
            unitPricePiastres: line.costPiastres,
          ),
      ],
      subtotalPiastres: expense.totalPiastres,
      totalPiastres: expense.totalPiastres,
      createdAt: expense.createdAt,
      username: expense.username,
      stockUpdated: true,
      status: ReceiptStatus.expense,
    );
  }

  /// Builds CSV rows from a list of receipts (sales and expenses).
  /// Each item in a receipt gets its own row.
  List<List<String>> _buildCsvRows(List<ReceiptEntity> receipts) {
    final rows = <List<String>>[
      [
        'Type',
        'Date',
        'Order #',
        'Item',
        'Quantity',
        'Price (EGP)',
        'Total (EGP)',
      ],
    ];

    for (final receipt in receipts) {
      final type = receipt.status == ReceiptStatus.expense ? 'Expense' : 'Sale';
      final date =
          '${receipt.createdAt.day}/${receipt.createdAt.month}/${receipt.createdAt.year}';
      final orderNumber = receipt.orderNumber;

      for (final item in receipt.items) {
        final price = item.unitPricePiastres / 100; // Convert piastres to EGP
        final total = price * item.quantity;
        rows.add([
          type,
          date,
          orderNumber,
          item.name,
          item.quantity.toString(),
          price.toStringAsFixed(2),
          total.toStringAsFixed(2),
        ]);
      }
    }

    return rows;
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
