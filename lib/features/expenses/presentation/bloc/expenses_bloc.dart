import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/audit/audit_event.dart';
import '../../../../core/audit/audit_service.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/domain/helpers/barcode_generator.dart';
import '../../../inventory/domain/repositories/i_inventory_repository.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/i_expenses_repository.dart';
import 'expenses_event.dart';
import 'expenses_state.dart';

class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc({
    required IExpensesRepository expensesRepo,
    required IInventoryRepository inventoryRepo,
    String Function()? generateId,
    String Function()? getCurrentShiftId,
    AuditService? auditService,
  }) : _expensesRepo = expensesRepo,
       _inventoryRepo = inventoryRepo,
       _generateId = generateId ?? (() => const Uuid().v4()),
       _getCurrentShiftId = getCurrentShiftId ?? (() => ''),
       _auditService = auditService,
       super(const ExpensesState()) {
    on<CreateExpense>(_onCreateExpense);
  }

  final IExpensesRepository _expensesRepo;
  final IInventoryRepository _inventoryRepo;
  final String Function() _generateId;
  final String Function() _getCurrentShiftId;
  final AuditService? _auditService;

  Future<String> suggestExpenseName({String? shiftId}) async {
    final id = shiftId ?? _getCurrentShiftId();
    if (id.isEmpty) return _formatExpenseName(1);
    final count = await _expensesRepo.getByShift(id);
    return _formatExpenseName(count.fold((_) => 1, (list) => list.length + 1));
  }

  String _formatExpenseName(int n) => 'EXP-${n.toString().padLeft(5, '0')}';

  Future<void> _onCreateExpense(
    CreateExpense event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.loading, clearFailure: true));
    try {
      final shiftId = _getCurrentShiftId();
      if (shiftId.isEmpty) {
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            failure: ValidationFailure(
              'No active shift',
              field: 'shiftId',
              reason: 'no_active_shift',
            ),
          ),
        );
        return;
      }
      if (event.items.isEmpty) {
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            failure: ValidationFailure(
              'Expense items cannot be empty',
              field: 'items',
              reason: 'empty',
            ),
          ),
        );
        return;
      }
      var totalPiastres = 0;
      for (final item in event.items) {
        if (item.quantity < 1 || item.costPiastres < 0) {
          emit(
            state.copyWith(
              status: ExpenseBlocStatus.error,
              failure: ValidationFailure(
                'Invalid expense item',
                field: 'items',
                reason: 'invalid_line',
              ),
            ),
          );
          return;
        }
        totalPiastres += item.quantity * item.costPiastres;
      }
      if (totalPiastres <= 0) {
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            failure: ValidationFailure(
              'Expense total must be greater than zero',
              field: 'costPiastres',
              reason: 'zero_amount',
            ),
          ),
        );
        return;
      }

      final existingInventory = await _inventoryRepo.getInventory();
      final takenBarcodes = existingInventory.fold(
        (_) => <String>{},
        (inventory) => inventory.keys.toSet(),
      );
      final generatedBarcodes = <String>{};
      final lines = <ExpenseLineEntity>[];
      for (final item in event.items) {
        var barcode = item.barcode;
        if (barcode.isEmpty) {
          barcode = generateNumericBarcode(
            isTaken: (b) =>
                takenBarcodes.contains(b) || generatedBarcodes.contains(b),
          );
          generatedBarcodes.add(barcode);
        }
        lines.add(
          ExpenseLineEntity(
            barcode: barcode,
            name: item.name,
            quantity: item.quantity,
            costPiastres: item.costPiastres,
          ),
        );
      }
      final expense = ExpenseEntity(
        id: _generateId(),
        shiftId: shiftId,
        username: event.username,
        lines: lines,
        createdAt: DateTime.now(),
        name: event.name.trim().isEmpty
            ? await suggestExpenseName(shiftId: shiftId)
            : event.name.trim(),
      );

      final saveResult = await _expensesRepo.save(expense);
      final saveFailure = saveResult.fold((f) => f, (_) => null);
      if (saveFailure != null) {
        emit(
          state.copyWith(status: ExpenseBlocStatus.error, failure: saveFailure),
        );
        return;
      }

      var stockFailures = 0;
      for (final item in event.items) {
        final line = lines[event.items.indexOf(item)];
        final Either<Failure, void> result;
        if (item.barcode.isEmpty) {
          result = await _inventoryRepo.saveProduct(
            ProductEntity(
              barcode: line.barcode,
              name: item.name,
              price: 0,
              stock: item.quantity,
            ),
          );
        } else {
          result = await _inventoryRepo.updateStock(
            item.barcode,
            item.quantity,
          );
        }
        if (result.fold((f) => f, (_) => null) != null) {
          stockFailures++;
        }
      }
      if (stockFailures > 0) {
        _auditService?.log(
          AuditEventType.stockUpdateFailed,
          username: event.username,
          details:
              'Expense ${expense.id}: stock update failed for $stockFailures item(s)',
          success: false,
        );
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            failure: DatabaseFailure(
              'Stock update failed for $stockFailures item(s)',
            ),
          ),
        );
        return;
      }

      _auditService?.log(
        AuditEventType.expenseCreated,
        username: event.username,
        details:
            'Expense ${expense.id}: ${expense.lines.length} lines, ${expense.totalPiastres}pt',
      );
      emit(
        state.copyWith(
          status: ExpenseBlocStatus.ready,
          expenses: [...state.expenses, expense],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ExpenseBlocStatus.error,
          failure: DatabaseFailure('CreateExpense failed: $e'),
        ),
      );
    }
  }
}
