import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/i_expenses_repository.dart';
import '../models/app_expense_model.dart';

class ExpensesRepositoryImpl implements IExpensesRepository {
  ExpensesRepositoryImpl({required LazyBox<AppExpenseModel> box}) : _box = box;

  final LazyBox<AppExpenseModel> _box;

  @override
  Future<Either<Failure, void>> save(ExpenseEntity expense) async {
    try {
      await _box.put(
        expense.id,
        AppExpenseModel(
          id: expense.id,
          shiftId: expense.shiftId,
          username: expense.username,
          lines: expense.lines,
          createdAt: expense.createdAt,
          name: expense.name,
        ),
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save expense', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getAll({int? limit}) async {
    try {
      final list = <ExpenseEntity>[];
      final count = _box.length;
      final max = limit ?? count;
      for (var i = count - 1; i >= 0 && list.length < max; i--) {
        final m = (await _box.getAt(i))!;
        list.add(m.toEntity());
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load expenses', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByShift(
    String shiftId,
  ) async {
    try {
      final list = <ExpenseEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = (await _box.getAt(i))!;
        if (m.shiftId == shiftId) {
          list.add(m.toEntity());
        }
      }
      return Right(list);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to load expenses for shift', cause: e),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByDate(DateTime date) async {
    try {
      final list = <ExpenseEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = (await _box.getAt(i))!;
        final d = m.createdAt;
        if (d.year == date.year && d.month == date.month && d.day == date.day) {
          list.add(m.toEntity());
        }
      }
      return Right(list);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to load expenses for date', cause: e),
      );
    }
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getByMonth(
    int year,
    int month,
  ) async {
    try {
      final list = <ExpenseEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = (await _box.getAt(i))!;
        if (m.createdAt.year == year && m.createdAt.month == month) {
          list.add(m.toEntity());
        }
      }
      return Right(list);
    } catch (e) {
      return Left(
        DatabaseFailure('Failed to load expenses for month', cause: e),
      );
    }
  }
}
