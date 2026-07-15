import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../receipts/domain/repositories/receipts_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final IReceiptsRepository _receiptsRepo;

  SalesBloc({required IReceiptsRepository receiptsRepo})
      : _receiptsRepo = receiptsRepo,
        super(const SalesState()) {
    on<LoadTodaySummary>(_onLoadTodaySummary);
    on<LoadMonth>(_onLoadMonth);
    on<LoadShiftReceipts>(_onLoadShiftReceipts);
  }

  Future<void> _onLoadTodaySummary(
      LoadTodaySummary event, Emitter<SalesState> emit) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    final today = DateTime.now();
    final result = await _receiptsRepo.getByDate(today);

    result.fold(
      (failure) => emit(state.copyWith(status: SalesStatus.error, failure: failure)),
      (receipts) {
        final totalPiastres = receipts.fold<int>(0, (sum, r) => sum + r.totalPiastres);
        final itemsSold = receipts.fold<int>(0, (sum, r) => sum + r.items.fold<int>(0, (s, i) => s + i.quantity));
        emit(state.copyWith(
          status: SalesStatus.ready,
          todaySummary: TodaySummary(
            totalPiastres: totalPiastres,
            receiptCount: receipts.length,
            itemsSold: itemsSold,
          ),
        ));
      },
    );
  }

  Future<void> _onLoadMonth(
      LoadMonth event, Emitter<SalesState> emit) async {
    emit(state.copyWith(
      status: SalesStatus.loading,
      clearMonthData: true,
      clearFailure: true,
    ));

    final result = await _receiptsRepo.getByMonth(event.year, event.month);

    result.fold(
      (failure) => emit(state.copyWith(status: SalesStatus.error, failure: failure)),
      (receipts) {
        final totalPiastres =
            receipts.fold<int>(0, (sum, r) => sum + r.totalPiastres);
        final monthData = MonthData(
          year: event.year,
          month: event.month,
          totalPiastres: totalPiastres,
          receiptCount: receipts.length,
          receipts: receipts,
        );
        emit(state.copyWith(
          status: SalesStatus.ready,
          monthData: monthData,
          months: [
            ...state.months.where(
                (m) => !(m.year == event.year && m.month == event.month)),
            monthData,
          ]..sort((a, b) => b.year != a.year
              ? b.year.compareTo(a.year)
              : b.month.compareTo(a.month)),
        ));
      },
    );
  }

  Future<void> _onLoadShiftReceipts(
      LoadShiftReceipts event, Emitter<SalesState> emit) async {
    emit(state.copyWith(status: SalesStatus.loading, clearFailure: true));

    Failure? failure;
    final result = await _receiptsRepo.getByShift(event.shiftId);

    result.fold(
      (l) => failure = l,
      (r) {
        r.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        emit(state.copyWith(status: SalesStatus.ready, shiftReceipts: r));
      },
    );

    if (failure != null) {
      emit(state.copyWith(status: SalesStatus.error, failure: failure));
    }
  }
}
