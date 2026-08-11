import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/expenses/domain/entities/expense_entity.dart';
import 'package:cashier_system/features/expenses/domain/repositories/i_expenses_repository.dart';

class FakeExpensesRepository implements IExpensesRepository {
  final Map<String, ExpenseEntity> _expenses = {};

  Map<String, ExpenseEntity> get expenses => _expenses;

  @override
  Future<Either<Failure, void>> save(ExpenseEntity expense) async {
    _expenses[expense.id] = expense;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getAll({int? limit}) async {
    final list = _expenses.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Right(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByShift(
    String shiftId,
  ) async =>
      Right(_expenses.values.where((e) => e.shiftId == shiftId).toList());

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByDate(DateTime date) async =>
      Right(
        _expenses.values
            .where(
              (e) =>
                  e.createdAt.year == date.year &&
                  e.createdAt.month == date.month &&
                  e.createdAt.day == date.day,
            )
            .toList(),
      );

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByMonth(
    int year,
    int month,
  ) async => Right(
    _expenses.values
        .where((e) => e.createdAt.year == year && e.createdAt.month == month)
        .toList(),
  );
}

class FailingFakeExpensesRepository extends FakeExpensesRepository {
  @override
  Future<Either<Failure, void>> save(ExpenseEntity expense) async =>
      const Left(DatabaseFailure('Save failed'));
}
