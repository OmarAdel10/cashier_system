import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/audit/audit_event.dart';
import '../../../../core/audit/audit_service.dart';
import '../../../../core/error/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/domain/repositories/i_auth_repository.dart';
import '../../../inventory/domain/repositories/i_inventory_repository.dart';
import '../../domain/entities/receipt_entity.dart';
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
  final IAuthRepository _authRepo;
  final String Function() _generateId;
  final String Function() _getCurrentShiftId;
  final AuditService? _auditService;
  bool _isProcessing = false;

  ReceiptsBloc({
    required IReceiptsRepository receiptsRepo,
    required IInventoryRepository inventoryRepo,
    required IRefundsRepository refundsRepo,
    required IAuthRepository authRepo,
    String Function()? generateId,
    String Function()? getCurrentShiftId,
    AuditService? auditService,
  }) : _receiptsRepo = receiptsRepo,
       _inventoryRepo = inventoryRepo,
       _refundsRepo = refundsRepo,
       _authRepo = authRepo,
       _generateId = generateId ?? (() => const Uuid().v4()),
       _getCurrentShiftId = getCurrentShiftId ?? (() => ''),
       _auditService = auditService,
       super(const ReceiptsState()) {
    on<CreateReceipt>(_onCreateReceipt);
    on<LoadReceipts>(_onLoadReceipts);
    on<LoadReceiptsByMonth>(_onLoadReceiptsByMonth);
    on<ProcessRefund>(_onProcessRefund);
    on<ModifyReceipt>(_onModifyReceipt);
    on<AuthorizedModifyReceipt>(_onAuthorizedModifyReceipt);
  }

  Future<void> retryPendingStockUpdates() async {
    final result = await _receiptsRepo.getByStockNotUpdated();
    final receipts = result.fold((_) => <ReceiptEntity>[], (r) => r);
    for (final receipt in receipts) {
      final stockFailures = <Failure>[];
      for (final item in receipt.items) {
        final r = await _inventoryRepo.updateStock(item.barcode, -item.quantity);
        r.fold((l) => stockFailures.add(l), (_) {});
      }
      if (stockFailures.isEmpty) {
        final updated = receipt.copyWith(stockUpdated: true);
        await _receiptsRepo.save(updated);
        debugPrint('[Receipts] Stock retry OK: receipt ${receipt.id}');
        _auditService?.log(
          AuditEventType.stockRetryResolved,
          details: 'Receipt ${receipt.id}: pending stock update resolved',
        );
      } else {
        debugPrint('[Receipts] Stock retry FAILED: receipt ${receipt.id}, ${stockFailures.length} items');
      }
    }
  }

  Future<void> _onCreateReceipt(
    CreateReceipt event,
    Emitter<ReceiptsState> emit,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      emit(
        state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true),
      );

      final computed = event.items.fold(
        0,
        (s, i) => s + i.quantity * i.unitPricePiastres,
      );
      if (computed != event.subtotalPiastres) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const ValidationFailure(
              'Subtotal mismatch',
              field: 'subtotalPiastres',
              reason: 'computed_value_does_not_match',
            ),
          ),
        );
        return;
      }

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
        emit(
          state.copyWith(status: ReceiptBlocStatus.error, failure: saveFailure),
        );
        return;
      }

      final List<Failure> stockFailures = [];
      for (final item in event.items) {
        final result = await _inventoryRepo.updateStock(
          item.barcode,
          -item.quantity,
        );
        result.fold((l) => stockFailures.add(l), (_) {});
      }

      final anyStockFailed = stockFailures.isNotEmpty;
      final updated = receipt.copyWith(stockUpdated: !anyStockFailed);
      await _receiptsRepo.save(updated);

      if (anyStockFailed) {
        _auditService?.log(
          AuditEventType.stockUpdateFailed,
          username: event.username,
          details: 'Receipt ${receipt.id}: stock update failed for ${stockFailures.length} item(s)',
          success: false,
        );
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: DatabaseFailure(
              'Stock update failed for ${stockFailures.length} item(s)',
            ),
          ),
        );
        return;
      }

      _auditService?.log(
        AuditEventType.receiptCreated,
        username: event.username,
        details: 'Receipt ${receipt.id}: ${event.items.length} items, ${event.totalPiastres}pt',
      );

      final currentReceipts = state.receipts ?? [];
      emit(
        state.copyWith(
          status: ReceiptBlocStatus.ready,
          receipts: [...currentReceipts, updated],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReceiptBlocStatus.error,
          failure: DatabaseFailure('CreateReceipt failed: $e'),
        ),
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onLoadReceipts(
    LoadReceipts event,
    Emitter<ReceiptsState> emit,
  ) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));
    Failure? loadFailure;
    final result = await _receiptsRepo.getAll();
    result.fold((l) => loadFailure = l, (r) {
      emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: r));
    });
    if (loadFailure != null) {
      emit(
        state.copyWith(status: ReceiptBlocStatus.error, failure: loadFailure),
      );
    }
  }

  Future<void> _onLoadReceiptsByMonth(
    LoadReceiptsByMonth event,
    Emitter<ReceiptsState> emit,
  ) async {
    emit(state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true));
    Failure? loadFailure;
    final result = await _receiptsRepo.getByMonth(event.year, event.month);
    result.fold((l) => loadFailure = l, (r) {
      emit(state.copyWith(status: ReceiptBlocStatus.ready, receipts: r));
    });
    if (loadFailure != null) {
      emit(
        state.copyWith(status: ReceiptBlocStatus.error, failure: loadFailure),
      );
    }
  }

  Future<void> _onProcessRefund(
    ProcessRefund event,
    Emitter<ReceiptsState> emit,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      emit(
        state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true),
      );

      if (event.receipt.status == ReceiptStatus.returned) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: RefundLockFailure(
              'Cannot modify a receipt with status ${event.receipt.status.name}',
              receiptId: event.receipt.id,
              currentStatus: event.receipt.status,
            ),
          ),
        );
        return;
      }

      if (event.receipt.shiftId != _getCurrentShiftId()) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: RefundLockFailure(
              'Refund blocked: receipt belongs to a different shift',
              receiptId: event.receipt.id,
              currentStatus: event.receipt.status,
            ),
          ),
        );
        return;
      }

      final List<Failure> stockFailures = [];
      for (final item in event.receipt.items) {
        final result = await _inventoryRepo.updateStock(
          item.barcode,
          item.quantity,
        );
        result.fold((l) => stockFailures.add(l), (_) {});
      }
      if (stockFailures.isNotEmpty) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: DatabaseFailure(
              'Stock restoration failed for ${stockFailures.length} item(s)',
            ),
          ),
        );
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

      final currentReceipts = state.receipts ?? [];
      final newReceipts = currentReceipts
          .map((r) => r.id == event.receipt.id ? updated : r)
          .toList();
      emit(
        state.copyWith(status: ReceiptBlocStatus.ready, receipts: newReceipts),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReceiptBlocStatus.error,
          failure: DatabaseFailure('ProcessRefund failed: $e'),
        ),
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onModifyReceipt(
    ModifyReceipt event,
    Emitter<ReceiptsState> emit,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      emit(
        state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true),
      );

      if (event.receipt.status != ReceiptStatus.active) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: RefundLockFailure(
              'Cannot modify a receipt with status ${event.receipt.status.name}',
              receiptId: event.receipt.id,
              currentStatus: event.receipt.status,
            ),
          ),
        );
        return;
      }

      final computed = event.items.fold(
        0,
        (s, i) => s + i.quantity * i.unitPricePiastres,
      );
      if (computed != event.subtotalPiastres) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const ValidationFailure(
              'Subtotal mismatch on modify',
              field: 'subtotalPiastres',
              reason: 'computed_value_does_not_match',
            ),
          ),
        );
        return;
      }

      final List<Failure> stockFailures = [];
      for (final newItem in event.items) {
        final oldItemIndex = event.receipt.items.indexWhere(
          (i) => i.barcode == newItem.barcode,
        );
        if (oldItemIndex == -1) {
          emit(
            state.copyWith(
              status: ReceiptBlocStatus.error,
              failure: DatabaseFailure(
                'Item ${newItem.barcode} not found in original receipt',
              ),
            ),
          );
          return;
        }
        final oldItem = event.receipt.items[oldItemIndex];
        final delta = oldItem.quantity - newItem.quantity;
        if (delta != 0) {
          final result = await _inventoryRepo.updateStock(
            newItem.barcode,
            delta,
          );
          result.fold((l) => stockFailures.add(l), (_) {});
        }
      }
      if (stockFailures.isNotEmpty) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: DatabaseFailure(
              'Stock update failed during modify for ${stockFailures.length} item(s)',
            ),
          ),
        );
        return;
      }

      final updated = event.receipt.copyWith(
        items: event.items,
        subtotalPiastres: event.subtotalPiastres,
        discountPiastres: event.discountPiastres,
        taxPiastres: event.taxPiastres,
        totalPiastres: event.totalPiastres,
        status: ReceiptStatus.modified,
        modificationCount: event.receipt.modificationCount + 1,
      );
      await _receiptsRepo.save(updated);

      final currentReceipts = state.receipts ?? [];
      final newReceipts = currentReceipts
          .map((r) => r.id == event.receipt.id ? updated : r)
          .toList();
      emit(
        state.copyWith(status: ReceiptBlocStatus.ready, receipts: newReceipts),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReceiptBlocStatus.error,
          failure: DatabaseFailure('ModifyReceipt failed: $e'),
        ),
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onAuthorizedModifyReceipt(
    AuthorizedModifyReceipt event,
    Emitter<ReceiptsState> emit,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      emit(
        state.copyWith(status: ReceiptBlocStatus.loading, clearFailure: true),
      );

      if (event.receipt.status == ReceiptStatus.returned) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: RefundLockFailure(
              'Cannot modify a receipt with status ${event.receipt.status.name}',
              receiptId: event.receipt.id,
              currentStatus: event.receipt.status,
            ),
          ),
        );
        return;
      }

      final adminResult = await _authRepo.getByUsername(event.adminUsername);
      Failure? authFailure;
      UserEntity? adminUser;
      adminResult.fold((l) => authFailure = l, (r) => adminUser = r);
      if (authFailure != null || adminUser == null) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const AuthenticationFailure(
              'Admin verification failed',
              AuthFailureReason.invalidCredentials,
            ),
          ),
        );
        return;
      }
      if (adminUser!.role != UserRole.admin) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const AuthenticationFailure(
              'User is not admin',
              AuthFailureReason.unauthorized,
            ),
          ),
        );
        return;
      }
      if (adminUser!.passwordHash != event.adminPassword) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const AuthenticationFailure(
              'Invalid admin password',
              AuthFailureReason.unauthorized,
            ),
          ),
        );
        return;
      }

      final computed = event.items.fold(
        0,
        (s, i) => s + i.quantity * i.unitPricePiastres,
      );
      if (computed != event.subtotalPiastres) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: const ValidationFailure(
              'Subtotal mismatch on authorized modify',
              field: 'subtotalPiastres',
              reason: 'computed_value_does_not_match',
            ),
          ),
        );
        return;
      }

      final List<Failure> stockFailures = [];
      for (final newItem in event.items) {
        final oldItemIndex = event.receipt.items.indexWhere(
          (i) => i.barcode == newItem.barcode,
        );
        if (oldItemIndex == -1) {
          emit(
            state.copyWith(
              status: ReceiptBlocStatus.error,
              failure: DatabaseFailure(
                'Item ${newItem.barcode} not found in original receipt',
              ),
            ),
          );
          return;
        }
        final oldItem = event.receipt.items[oldItemIndex];
        final delta = oldItem.quantity - newItem.quantity;
        if (delta != 0) {
          final result = await _inventoryRepo.updateStock(
            newItem.barcode,
            delta,
          );
          result.fold((l) => stockFailures.add(l), (_) {});
        }
      }
      if (stockFailures.isNotEmpty) {
        emit(
          state.copyWith(
            status: ReceiptBlocStatus.error,
            failure: DatabaseFailure(
              'Stock update failed during authorized modify for ${stockFailures.length} item(s)',
            ),
          ),
        );
        return;
      }

      final updated = event.receipt.copyWith(
        items: event.items,
        subtotalPiastres: event.subtotalPiastres,
        discountPiastres: event.discountPiastres,
        taxPiastres: event.taxPiastres,
        totalPiastres: event.totalPiastres,
        status: ReceiptStatus.modified,
        modificationCount: event.receipt.modificationCount + 1,
      );
      await _receiptsRepo.save(updated);

      final currentReceipts = state.receipts ?? [];
      final newReceipts = currentReceipts
          .map((r) => r.id == event.receipt.id ? updated : r)
          .toList();
      emit(
        state.copyWith(status: ReceiptBlocStatus.ready, receipts: newReceipts),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReceiptBlocStatus.error,
          failure: DatabaseFailure('AuthorizedModifyReceipt failed: $e'),
        ),
      );
    } finally {
      _isProcessing = false;
    }
  }
}
