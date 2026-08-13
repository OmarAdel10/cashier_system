import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/expenses/data/models/app_expense_model.dart';
import 'package:cashier_system/features/expenses/data/repositories/expenses_repository_impl.dart';
import 'package:cashier_system/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late LazyBox<AppExpenseModel> box;
  late ExpensesRepositoryImpl repository;

  ExpenseEntity makeExpense({
    String id = 'exp-1',
    String shiftId = 's1',
    String username = 'cashier1',
    DateTime? createdAt,
    int quantity = 2,
    int costPiastres = 1500,
  }) {
    return ExpenseEntity(
      id: id,
      shiftId: shiftId,
      username: username,
      lines: [
        ExpenseLineEntity(
          barcode: '111',
          name: 'Bread',
          quantity: quantity,
          costPiastres: costPiastres,
        ),
      ],
      createdAt: createdAt ?? DateTime(2026, 8, 11, 10, 0),
    );
  }

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppExpenseModelAdapter());
  });

  setUp(() async {
    box = await Hive.openLazyBox<AppExpenseModel>('test_expenses_repo');
    repository = ExpensesRepositoryImpl(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_expenses_repo');
  });

  test('save persists the expense', () async {
    final expense = makeExpense();
    final result = await repository.save(expense);
    expect(result, isA<Right<Failure, void>>());
    final loaded = (await repository.getAll()).fold(
      (f) => throw f,
      (list) => list,
    );
    expect(loaded.length, 1);
    expect(loaded.first.id, 'exp-1');
    expect(loaded.first.totalPiastres, 3000);
  });

  test('getAll returns newest first with limit', () async {
    await repository.save(
      makeExpense(id: 'a', createdAt: DateTime(2026, 8, 11, 9)),
    );
    await repository.save(
      makeExpense(id: 'b', createdAt: DateTime(2026, 8, 12, 9)),
    );
    await repository.save(
      makeExpense(id: 'c', createdAt: DateTime(2026, 8, 13, 9)),
    );
    final all = (await repository.getAll()).fold((f) => throw f, (l) => l);
    expect(all.map((e) => e.id).toList(), ['c', 'b', 'a']);
    final limited = (await repository.getAll(
      limit: 2,
    )).fold((f) => throw f, (l) => l);
    expect(limited.map((e) => e.id).toList(), ['c', 'b']);
  });

  test('getByShift filters by shiftId', () async {
    await repository.save(makeExpense(id: 'a', shiftId: 's1'));
    await repository.save(makeExpense(id: 'b', shiftId: 's2'));
    final result = (await repository.getByShift(
      's2',
    )).fold((f) => throw f, (l) => l);
    expect(result.map((e) => e.id).toList(), ['b']);
  });

  test('getByDate matches year, month and day', () async {
    await repository.save(
      makeExpense(id: 'a', createdAt: DateTime(2026, 8, 11, 10)),
    );
    await repository.save(
      makeExpense(id: 'b', createdAt: DateTime(2026, 8, 12, 10)),
    );
    await repository.save(
      makeExpense(id: 'c', createdAt: DateTime(2026, 9, 11, 10)),
    );
    final result = (await repository.getByDate(
      DateTime(2026, 8, 11, 23, 59),
    )).fold((f) => throw f, (l) => l);
    expect(result.map((e) => e.id).toList(), ['a']);
  });

  test('getByMonth matches year and month', () async {
    await repository.save(
      makeExpense(id: 'a', createdAt: DateTime(2026, 8, 1)),
    );
    await repository.save(
      makeExpense(id: 'b', createdAt: DateTime(2026, 8, 31)),
    );
    await repository.save(
      makeExpense(id: 'c', createdAt: DateTime(2026, 7, 31)),
    );
    final result = (await repository.getByMonth(
      2026,
      8,
    )).fold((f) => throw f, (l) => l);
    expect(result.map((e) => e.id).toSet(), {'a', 'b'});
  });
}
