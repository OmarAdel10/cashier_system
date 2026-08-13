import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/expense_entity.dart';

abstract class IExpensesRepository {
  Future<Either<Failure, void>> save(ExpenseEntity expense);

  Future<Either<Failure, List<ExpenseEntity>>> getAll({int? limit});

  Future<Either<Failure, List<ExpenseEntity>>> getByShift(String shiftId);

  Future<Either<Failure, List<ExpenseEntity>>> getByDate(DateTime date);

  Future<Either<Failure, List<ExpenseEntity>>> getByMonth(int year, int month);
}
