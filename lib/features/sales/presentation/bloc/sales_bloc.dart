import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/exports/csv_writer.dart';
import '../../../../core/exports/pdf_generator.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../auth/domain/entities/shift_entity.dart';
import '../../../auth/domain/repositories/i_shifts_repository.dart';
import '../../../checkout/domain/repositories/i_session_record_repository.dart';
import '../../../inventory/domain/repositories/i_inventory_repository.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/domain/entities/receipt_status.dart';
import '../../../receipts/domain/repositories/receipts_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final IReceiptsRepository _receiptsRepo;
  final IShiftsRepository _shiftsRepo;
  final ISessionRecordRepository? _sessionRecordsRepo;
  final IInventoryRepository? _inventoryRepo;
  final Map<String, int> _costCache = {};

  SalesBloc({
    required IReceiptsRepository receiptsRepo,
    required IShiftsRepository shiftsRepo,
    ISessionRecordRepository? sessionRecordsRepo,
    IInventoryRepository? inventoryRepo,
  }) : _receiptsRepo = receiptsRepo,
       _shiftsRepo = shiftsRepo,
       _sessionRecordsRepo = sessionRecordsRepo,
       _inventoryRepo = inventoryRepo,
       super(const SalesState()) {
    on<LoadTodaySummary>(_onLoadTodaySummary);
    on<LoadMonth>(_onLoadMonth);
    on<LoadShiftReceipts>(_onLoadShiftReceipts);
    on<LoadSessionRecords>(_onLoadSessionRecords);
  }

  Future<void> _onLoadTodaySummary(
    LoadTodaySummary event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    final today = DateTime.now();
    final result = await _receiptsRepo.getByDate(today);

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
    final costMap = await _loadCostMap(activeReceipts);
    final (profitPiastres, unknownCostCount) = _profitOf(
      activeReceipts,
      includeTaxInProfit: event.includeTaxInProfit,
      costMap: costMap,
    );
    emit(
      state.copyWith(
        status: SalesStatus.ready,
        todaySummary: TodaySummary(
          totalPiastres: totalPiastres,
          receiptCount: activeReceipts.length,
          itemsSold: itemsSold,
          profitPiastres: profitPiastres,
          taxPiastres: activeReceipts.fold<int>(
            0,
            (sum, r) => sum + r.taxPiastres,
          ),
          unknownCostCount: unknownCostCount,
        ),
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

      groupedDays.add(DayGroup(date: day, cashiers: cashierGroups));
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
    final costMap = await _loadCostMap(activeReceipts);
    final (profitPiastres, unknownCostCount) = _profitOf(
      activeReceipts,
      includeTaxInProfit: event.includeTaxInProfit,
      costMap: costMap,
    );

    final monthGroupedData = MonthGroupedData(
      year: event.year,
      month: event.month,
      totalPiastres: totalPiastres,
      receiptCount: activeReceipts.length,
      itemsSold: itemsSold,
      profitPiastres: profitPiastres,
      unknownCostCount: unknownCostCount,
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
      ),
    );
  }

  Future<void> _onLoadShiftReceipts(
    LoadShiftReceipts event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    Failure? failure;
    final result = await _receiptsRepo.getByShift(event.shiftId);

    result.fold((l) => failure = l, (r) {
      r.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(status: SalesStatus.ready, shiftReceipts: r));
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

  Future<void> _onExportByMonth(ExportByMonth event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    final result = await _receiptsRepo.getByMonth(event.year, event.month);
    final receipts = result.fold(
      (f) => <ReceiptEntity>[],
      (r) => r,
    );

    // Save CSV and PDF files
    final csvPath = '${state.exportDirectoryPath}/sales_month_${event.year}_${event.month.toString().padLeft(2, '0')}.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_month_${event.year}_${event.month.toString().padLeft(2, '0')}.pdf';

    await writeCsvRows(_buildCsvRows(receipts), csvPath);
    await generateTablePdf(_buildPdfData(receipts), title: 'Sales Export - Month ${event.month}/${event.year}');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Future<void> _onExportByDay(ExportByDay event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    final date = DateTime(event.year, event.month, event.day);
    final result = await _receiptsRepo.getByDate(date);
    final receipts = result.fold(
      (f) => <ReceiptEntity>[],
      (r) => r,
    );

    // Save CSV and PDF files
    final csvPath = '${state.exportDirectoryPath}/sales_day_${event.year}_${event.month.toString().padLeft(2, '0')}_${event.day}.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_day_${event.year}_${event.month.toString().padLeft(2, '0')}_${event.day}.pdf';

    await writeCsvRows(_buildCsvRows(receipts), csvPath);
    await generateTablePdf(_buildPdfData(receipts), title: 'Sales Export - Day ${event.day}/${event.month}/${event.year}');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Future<void> _onExportAllMonths(ExportAllMonths event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    // TODO: Implement fetching all months
    final result = await _receiptsRepo.getByMonth(DateTime.now().year, DateTime.now().month);
    final receipts = result.fold((f) => <ReceiptEntity>[], (r) => r);

    final csvPath = '${state.exportDirectoryPath}/sales_all_months.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_all_months.pdf';

    await writeCsvRows(_buildCsvRows(_flattenReceipts(_getAllMonthMap())), csvPath);
    await generateTablePdf(_buildPdfData(_flattenReceipts(_getAllMonthMap())), title: 'Sales Export - All Months');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Future<void> _onExportByYear(ExportByYear event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    final result = await _receiptsRepo.getByYear(event.year);
    final receipts = result.fold(
      (f) => <ReceiptEntity>[],
      (r) => r,
    );

    // Save CSV and PDF files
    final csvPath = '${state.exportDirectoryPath}/sales_year_${event.year}.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_year_${event.year}.pdf';

    await writeCsvRows(_buildCsvRows(receipts), csvPath);
    await generateTablePdf(_buildPdfData(receipts), title: 'Sales Export - Year $event.year');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Future<void> _onExportMonthToMonth(ExportMonthToMonth event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    // TODO: Implement month-to-month export
    final result = await _receiptsRepo.getByMonth(DateTime.now().year, DateTime.now().month);
    final receipts = result.fold((f) => <ReceiptEntity>[], (r) => r);

    final csvPath = '${state.exportDirectoryPath}/sales_monthtomonth_${DateTime.now().year}.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_monthtomonth_${DateTime.now().year}.pdf';

    await writeCsvRows(_buildCsvRows(receipts), csvPath);
    await generateTablePdf(_buildPdfData(receipts), title: 'Sales Export - Month-to-Month');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Future<void> _onExportDayToDay(ExportDayToDay event, Emitter<SalesState> emit) async {
    emit(state.copyWith(exportProgress: ExportStatus.loading));

    // TODO: Implement day-to-day export
    final result = await _receiptsRepo.getByDate(DateTime.now());
    final receipts = result.fold((f) => <ReceiptEntity>[], (r) => r);

    final csvPath = '${state.exportDirectoryPath}/sales_daytoday_${DateTime.now().year}.csv';
    final pdfPath = '${state.exportDirectoryPath}/sales_daytoday_${DateTime.now().year}.pdf';

    await writeCsvRows(_buildCsvRows(receipts), csvPath);
    await generateTablePdf(_buildPdfData(receipts), title: 'Sales Export - Day-to-Day');

    emit(state.copyWith(
      exportProgress: ExportStatus.success,
      exportFilePath: csvPath,
      exportFormat: 'csv',
    ));
  }

  Map<int, List<ReceiptEntity>> _getAllMonthMap() {
    // TODO: Implement proper fetching of all months
    return {};
  }

  List<ReceiptEntity> _flattenReceipts(Map<int, List<ReceiptEntity>> monthsMap) {
    final all = <ReceiptEntity>[];
    monthsMap.values.forEach((receipts) => all.addAll(receipts));
    return all;
  }

  Future<Map<String, int>> _loadCostMap(List<ReceiptEntity> receipts) async {
    final repo = _inventoryRepo;
    if (repo == null) return const {};

    final barcodes = <String>{
      for (final r in receipts)
        for (final item in r.items) item.barcode,
    };
    if (barcodes.isEmpty) return const {};

    // Check cache first
    final missingBarcodes = barcodes
        .where((b) => !_costCache.containsKey(b))
        .toList();
    if (missingBarcodes.isNotEmpty) {
      final result = await repo.getInventory();
      result.fold((_) {}, (products) {
        for (final e in products.entries) {
          if (e.value.purchasePrice > 0) {
            _costCache[e.key] = (e.value.purchasePrice * 100).round();
          }
        }
      });
    }
    // Return only requested barcodes from cache
    return {
      for (final b in barcodes)
        if (_costCache.containsKey(b)) b: _costCache[b]!,
    };
  }

  (int profit, int unknownCostCount) _profitOf(
    List<ReceiptEntity> receipts, {
    required bool includeTaxInProfit,
    required Map<String, int> costMap,
  }) {
    var unknownCostCount = 0;
    final profit = receipts.fold<int>(0, (sum, r) {
      final revenue = includeTaxInProfit
          ? r.totalPiastres
          : r.totalPiastres - r.taxPiastres;
      var cost = 0;
      for (final item in r.items) {
        final unitCost = costMap[item.barcode];
        if (unitCost == null || unitCost <= 0) {
          unknownCostCount += item.quantity;
          cost += 0;
        } else {
          cost += unitCost * item.quantity;
        }
      }
      return sum + revenue - cost;
    });
    return (profit, unknownCostCount);
  }

  /// Builds CSV rows from a list of receipts
  List<List<String>> _buildCsvRows(List<ReceiptEntity> receipts) {
    // Header row
    final rows = <List<String>>[
      ['Date', 'Order #', 'Item', 'Quantity', 'Price (EGP)', 'Total (EGP)'],
    ];

    // Data rows
    for (final receipt in receipts) {
      final date = '${receipt.createdAt.day}/${receipt.createdAt.month}/${receipt.createdAt.year}';
      final orderNumber = receipt.orderNumber ?? 'N/A';

      for (final item in receipt.items) {
        final price = item.unitPricePiastres / 100; // Convert piastres to EGP
        final total = price * item.quantity;
        rows.add([
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

  /// Builds PDF data (as CSV-style rows) from a list of receipts
  List<List<String>> _buildPdfData(List<ReceiptEntity> receipts) {
    // Same structure as CSV for minimal PDF table
    return _buildCsvRows(receipts);
  }

  /// Gets all months map (placeholder implementation)
}
