import 'package:cashier_system/core/audit/audit_service.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:cashier_system/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:cashier_system/features/expenses/presentation/bloc/expenses_state.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../../inventory/helpers/fake_inventory_repository.dart';
import '../../helpers/fake_expenses_repository.dart';

void main() {
  late FakeExpensesRepository expensesRepo;
  late FakeInventoryRepository inventoryRepo;
  late ExpensesBloc bloc;

  setUpAll(() {
    Hive.init('test/_hive_test');
  });

  setUp(() async {
    expensesRepo = FakeExpensesRepository();
    inventoryRepo = FakeInventoryRepository();
    await inventoryRepo.saveProduct(
      ProductEntity(
        barcode: '123',
        name: 'Pen',
        price: 500,
        purchasePrice: 350,
        stock: 10,
      ),
    );
    bloc = ExpensesBloc(
      expensesRepo: expensesRepo,
      inventoryRepo: inventoryRepo,
      getCurrentShiftId: () => 's1',
      generateId: () => 'exp-test-1',
    );
  });

  tearDown(() => bloc.close());

  Future<Map<String, ProductEntity>> inventory() async =>
      (await inventoryRepo.getInventory()).fold(
        (_) => const <String, ProductEntity>{},
        (items) => items,
      );

  ExpenseItemInput existingLine() => const ExpenseItemInput(
    barcode: '123',
    name: 'Pen',
    quantity: 2,
    costPiastres: 350,
  );

  ExpenseItemInput newProductLine() => const ExpenseItemInput(
    barcode: '',
    name: 'Bread',
    quantity: 5,
    costPiastres: 1500,
  );

  test('initial state', () {
    expect(bloc.state.status, ExpenseBlocStatus.initial);
    expect(bloc.state.expenses, isEmpty);
  });

  test(
    'create expense with existing product saves and increases stock',
    () async {
      bloc.add(CreateExpense(username: 'cashier1', items: [existingLine()]));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ExpensesState>().having(
            (s) => s.status,
            'status',
            ExpenseBlocStatus.loading,
          ),
          isA<ExpensesState>()
              .having((s) => s.status, 'status', ExpenseBlocStatus.ready)
              .having((s) => s.expenses.length, 'expenses length', 1)
              .having((s) => s.expenses.first.totalPiastres, 'total', 700)
              .having((s) => s.expenses.first.shiftId, 'shiftId', 's1')
              .having((s) => s.expenses.first.username, 'username', 'cashier1'),
        ]),
      );
      expect(expensesRepo.expenses.length, 1);
      expect((await inventory())['123']!.stock, 12);
    },
  );

  test(
    'create expense with new product saves it with price 0 and stock qty',
    () async {
      bloc.add(CreateExpense(username: 'cashier1', items: [newProductLine()]));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ExpensesState>().having(
            (s) => s.status,
            'status',
            ExpenseBlocStatus.loading,
          ),
          isA<ExpensesState>()
              .having((s) => s.status, 'status', ExpenseBlocStatus.ready)
              .having((s) => s.expenses.first.totalPiastres, 'total', 7500),
        ]),
      );
      final created = (await inventory()).values.firstWhere(
        (p) => p.name == 'Bread',
      );
      expect(created.barcode, isNotEmpty);
      expect(created.price, 0);
      expect(created.purchasePrice, 15.0);
      expect(created.stock, 5);
    },
  );

  test('rejects when no active shift', () async {
    final noShiftBloc = ExpensesBloc(
      expensesRepo: expensesRepo,
      inventoryRepo: inventoryRepo,
      getCurrentShiftId: () => '',
      generateId: () => 'x',
    );
    noShiftBloc.add(
      CreateExpense(username: 'cashier1', items: [existingLine()]),
    );
    await expectLater(
      noShiftBloc.stream,
      emitsInOrder([
        isA<ExpensesState>().having(
          (s) => s.status,
          'status',
          ExpenseBlocStatus.loading,
        ),
        isA<ExpensesState>()
            .having((s) => s.status, 'status', ExpenseBlocStatus.error)
            .having((s) => s.failure, 'failure', isA<ValidationFailure>())
            .having(
              (s) => (s.failure as ValidationFailure).reason,
              'reason',
              'no_active_shift',
            ),
      ]),
    );
    expect(expensesRepo.expenses, isEmpty);
    await noShiftBloc.close();
  });

  test('rejects empty items', () async {
    bloc.add(const CreateExpense(username: 'cashier1', items: []));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ExpensesState>().having(
          (s) => s.status,
          'status',
          ExpenseBlocStatus.loading,
        ),
        isA<ExpensesState>()
            .having((s) => s.status, 'status', ExpenseBlocStatus.error)
            .having(
              (s) => (s.failure as ValidationFailure).reason,
              'reason',
              'empty',
            ),
      ]),
    );
    expect(expensesRepo.expenses, isEmpty);
  });

  test('rejects zero total', () async {
    bloc.add(
      const CreateExpense(
        username: 'cashier1',
        items: [
          ExpenseItemInput(
            barcode: '123',
            name: 'Pen',
            quantity: 1,
            costPiastres: 0,
          ),
        ],
      ),
    );
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ExpensesState>().having(
          (s) => s.status,
          'status',
          ExpenseBlocStatus.loading,
        ),
        isA<ExpensesState>()
            .having((s) => s.status, 'status', ExpenseBlocStatus.error)
            .having(
              (s) => (s.failure as ValidationFailure).reason,
              'reason',
              'zero_amount',
            ),
      ]),
    );
    expect(expensesRepo.expenses, isEmpty);
  });

  test('surfaces save failure', () async {
    final failBloc = ExpensesBloc(
      expensesRepo: FailingFakeExpensesRepository(),
      inventoryRepo: inventoryRepo,
      getCurrentShiftId: () => 's1',
    );
    failBloc.add(CreateExpense(username: 'cashier1', items: [existingLine()]));
    await expectLater(
      failBloc.stream,
      emitsInOrder([
        isA<ExpensesState>().having(
          (s) => s.status,
          'status',
          ExpenseBlocStatus.loading,
        ),
        isA<ExpensesState>()
            .having((s) => s.status, 'status', ExpenseBlocStatus.error)
            .having((s) => s.failure, 'failure', isA<DatabaseFailure>()),
      ]),
    );
    await failBloc.close();
  });

  test('surfaces stock failure but keeps the saved expense record', () async {
    bloc.add(
      const CreateExpense(
        username: 'cashier1',
        items: [
          ExpenseItemInput(
            barcode: 'missing',
            name: 'Ghost',
            quantity: 1,
            costPiastres: 500,
          ),
        ],
      ),
    );
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ExpensesState>().having(
          (s) => s.status,
          'status',
          ExpenseBlocStatus.loading,
        ),
        isA<ExpensesState>()
            .having((s) => s.status, 'status', ExpenseBlocStatus.error)
            .having((s) => s.failure, 'failure', isA<DatabaseFailure>()),
      ]),
    );
    expect(expensesRepo.expenses.length, 1);
  });

  test('logs audit events when auditService provided', () async {
    final auditBox = await Hive.openLazyBox<String>('test_audit_expenses');
    final service = AuditService(box: auditBox);
    final auditedBloc = ExpensesBloc(
      expensesRepo: expensesRepo,
      inventoryRepo: inventoryRepo,
      getCurrentShiftId: () => 's1',
      auditService: service,
    );
    auditedBloc.add(
      CreateExpense(username: 'cashier1', items: [existingLine()]),
    );
    await auditedBloc.stream.firstWhere(
      (s) => s.status == ExpenseBlocStatus.ready,
    );
    var entries = await service.getRecent();
    for (var attempt = 0; attempt < 50 && entries.isEmpty; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      entries = await service.getRecent();
    }
    expect(
      entries.any((e) => e.type.name == 'expenseCreated' && e.success),
      isTrue,
    );
    await auditedBloc.close();
    await auditBox.close();
    await Hive.deleteBoxFromDisk('test_audit_expenses');
  });
}
