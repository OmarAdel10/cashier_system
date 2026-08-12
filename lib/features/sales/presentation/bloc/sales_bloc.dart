import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../../auth/domain/entities/shift_entity.dart';
import '../../../auth/domain/repositories/i_shifts_repository.dart';
import '../../../checkout/domain/repositories/i_session_record_repository.dart';
import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/domain/entities/receipt_status.dart';
import '../../../receipts/domain/repositories/receipts_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';
import '../../../../features/expenses/domain/repositories/i_expenses_repository.dart';

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
  }

  Future<void> _onLoadTodaySummary(
    LoadTodaySummary event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true, clearExpenses: true));

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

    result.fold(
      (failure) =>
          emit(state.copyWith(status: SalesStatus.error, failure: failure)),
      (receipts) {
        final activeReceipts = receipts
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
            ),
            todayExpensesPiastres: todayExpensesPiastres,
          ),
        );
      },
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

    final totalPiastres = receipts!.fold<int>(
      0,
      (sum, r) => sum + r.totalPiastres,
    );
    final itemsSold = receipts!.fold<int>(
      0,
      (sum, r) => sum + r.items.fold<int>(0, (s, i) => s + i.quantity),
    );

    final monthGroupedData = MonthGroupedData(
      year: event.year,
      month: event.month,
      totalPiastres: totalPiastres,
      receiptCount: receipts!.length,
      itemsSold: itemsSold,
      days: groupedDays,
    );

    emit(
      state.copyWith(
        status: SalesStatus.ready,
        monthData: monthGroupedData,
        months:
            [
              ...state.months.where(
                (m) => !(m.year == event.year && m.month == event.month),
              ),
              monthGroupedData,
            ]..sort(
              (a, b) => b.year != a.year
                  ? b.year.compareTo(a.year)
                  : b.month.compareTo(a.month),
            ),
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
}
