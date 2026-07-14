import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../inventory/domain/repositories/i_inventory_repository.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/receipt_status.dart';
import '../../domain/entities/refund_entity.dart';
import '../../domain/repositories/receipts_repository.dart';
import '../../domain/repositories/refunds_repository.dart';
import 'receipts_event.dart';
import 'receipts_state.dart';

class ReceiptsBloc extends Bloc<ReceiptsEvent, ReceiptsState> {
  final IReceiptsRepository _receiptsRepo;
  final IInventoryRepository _inventoryRepo;
  final IRefundsRepository _refundsRepo;
  final String Function() _generateId;

  ReceiptsBloc({
    required IReceiptsRepository receiptsRepo,
    required IInventoryRepository inventoryRepo,
    required IRefundsRepository refundsRepo,
    String Function()? generateId,
  }) : _receiptsRepo = receiptsRepo,
       _inventoryRepo = inventoryRepo,
       _refundsRepo = refundsRepo,
       _generateId = generateId ?? (() => const Uuid().v4()),
       super(const ReceiptsState()) {
    on<CreateReceipt>(_onCreateReceipt);
    on<LoadReceipts>(_onLoadReceipts);
    on<LoadReceiptsByMonth>(_onLoadReceiptsByMonth);
    on<ProcessRefund>(_onProcessRefund);
    on<ModifyReceipt>(_onModifyReceipt);
  }

  Future<void> _onCreateReceipt(CreateReceipt event, Emitter<ReceiptsState> emit) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));

    final receipt = ReceiptEntity(
      id: _generateId(),
      shiftId: event.shiftId,
      orderNumber: event.orderNumber,
      items: event.items,
      subtotalPiastres: event.subtotalPiastres,
      discountPiastres: event.discountPiastres,
      taxPiastres: event.taxPiastres,
      totalPiastres: event.totalPiastres,
      createdAt: DateTime.now(),
      username: event.username,
      stockUpdated: false,
      status: ReceiptStatus.active,
    );

    Failure? saveFailure;
    final saveResult = await _receiptsRepo.save(receipt);
    saveResult.fold((l) => saveFailure = l, (_) {});
    if (saveFailure != null) {
      emit(state.copyWith(status: ReceiptBlocStatus.error, failure: saveFailure));
      return;
    }

    for (final item in event.items) {
      await _inventoryRepo.updateStock(item.barcode, -item.quantity);
    }

    final updated = receipt.copyWith(stockUpdated: true);
    await _receiptsRepo.save(updated);

    final currentReceipts = state.receipts ?? [];
    emit(state.copyWith(
      status: ReceiptBlocStatus.ready,
      receipts: [...currentReceipts, updated],
    ));
  }

  Future<void> _onLoadReceipts(LoadReceipts event, Emitter<ReceiptsState> emit) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));
    Failure? loadFailure;
    final result = await _receiptsRepo.getAll();
    result.fold((l) => loadFailure = l, (r) {
      emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: r));
    });
    if (loadFailure != null) {
      emit(state.copyWith(status: ReceiptBlocStatus.error, failure: loadFailure));
    }
  }

  Future<void> _onLoadReceiptsByMonth(LoadReceiptsByMonth event, Emitter<ReceiptsState> emit) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));
    Failure? loadFailure;
    final result = await _receiptsRepo.getByMonth(event.year, event.month);
    result.fold((l) => loadFailure = l, (r) {
      emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: r));
    });
    if (loadFailure != null) {
      emit(state.copyWith(status: ReceiptBlocStatus.error, failure: loadFailure));
    }
  }

  Future<void> _onProcessRefund(ProcessRefund event, Emitter<ReceiptsState> emit) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));

    if (event.receipt.status != ReceiptStatus.active) {
      emit(state.copyWith(
        status: ReceiptBlocStatus.error,
        failure: RefundLockFailure(
          'Refund blocked: receipt ${event.receipt.orderNumber} is ${event.receipt.status.name}',
          receiptId: event.receipt.id,
          currentStatus: event.receipt.status,
        ),
      ));
      return;
    }

    final refund = RefundEntity(
      id: _generateId(),
      originalReceiptId: event.receipt.id,
      refundDate: DateTime.now(),
      amountRestored: event.amountRestored,
      type: event.type,
    );

    final saveResult = await _refundsRepo.save(refund);
    Failure? failure;
    saveResult.fold((l) => failure = l, (_) {});
    if (failure != null) {
      emit(state.copyWith(status: ReceiptBlocStatus.error, failure: failure));
      return;
    }

    final updated = event.receipt.copyWith(status: ReceiptStatus.returned);
    await _receiptsRepo.save(updated);

    for (final item in event.receipt.items) {
      await _inventoryRepo.updateStock(item.barcode, item.quantity);
    }

    final currentReceipts = state.receipts ?? [];
    final newReceipts = currentReceipts.map((r) => r.id == event.receipt.id ? updated : r).toList();
    emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: newReceipts));
  }

  Future<void> _onModifyReceipt(ModifyReceipt event, Emitter<ReceiptsState> emit) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));

    if (event.receipt.status == ReceiptStatus.returned) {
      emit(state.copyWith(
        status: ReceiptBlocStatus.error,
        failure: const DatabaseFailure('Cannot modify a returned receipt'),
      ));
      return;
    }

    for (final newItem in event.items) {
      final oldItem = event.receipt.items.firstWhere(
        (i) => i.barcode == newItem.barcode,
        orElse: () => ReceiptItem(name: '', barcode: '', quantity: 0, unitPricePiastres: 0),
      );
      final delta = oldItem.quantity - newItem.quantity;
      if (delta != 0) {
        await _inventoryRepo.updateStock(newItem.barcode, delta);
      }
    }

    final updated = event.receipt.copyWith(
      items: event.items,
      subtotalPiastres: event.subtotalPiastres,
      discountPiastres: event.discountPiastres,
      taxPiastres: event.taxPiastres,
      totalPiastres: event.totalPiastres,
      status: ReceiptStatus.modified,
    );
    await _receiptsRepo.save(updated);

    final currentReceipts = state.receipts ?? [];
    final newReceipts = currentReceipts.map((r) => r.id == event.receipt.id ? updated : r).toList();
    emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: newReceipts));
  }
}
