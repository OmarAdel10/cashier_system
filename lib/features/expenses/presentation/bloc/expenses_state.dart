import '../../../../core/error/failure.dart';
import '../../domain/entities/expense_entity.dart';

enum ExpenseBlocStatus { initial, loading, ready, error }

class ExpensesState {
  const ExpensesState({
    this.status = ExpenseBlocStatus.initial,
    this.expenses = const [],
    this.failure,
  });

  final ExpenseBlocStatus status;
  final List<ExpenseEntity> expenses;
  final Failure? failure;

  ExpensesState copyWith({
    ExpenseBlocStatus? status,
    List<ExpenseEntity>? expenses,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpensesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          expenses == other.expenses &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, expenses, failure);

  @override
  String toString() =>
      'ExpensesState(status: $status, expenses: ${expenses.length}, failure: $failure)';
}
