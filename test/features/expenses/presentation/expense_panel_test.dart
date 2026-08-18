import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:cashier_system/features/expenses/presentation/expense_panel.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../expenses/helpers/fake_expenses_repository.dart';
import '../../inventory/helpers/fake_inventory_repository.dart';
import '../../settings/helpers/fake_settings_repository.dart';

void main() {
  late FakeExpensesRepository expensesRepo;
  late FakeInventoryRepository inventoryRepo;
  late ExpensesBloc expensesBloc;
  late InventoryBloc inventoryBloc;
  late SettingsBloc settingsBloc;

  final user = UserEntity(
    username: 'cashier1',
    passwordHash: '',
    mustChangePassword: false,
    role: UserRole.cashier,
    createdAt: DateTime(2026, 8, 11),
  );

  setUp(() {
    expensesRepo = FakeExpensesRepository();
    inventoryRepo = FakeInventoryRepository();
    inventoryRepo.saveProduct(
      ProductEntity(
        barcode: '123',
        name: 'Bread',
        price: 2000,
        purchasePrice: 15.0,
        stock: 20,
      ),
    );
    expensesBloc = ExpensesBloc(
      expensesRepo: expensesRepo,
      inventoryRepo: inventoryRepo,
      getCurrentShiftId: () => 's1',
      generateId: () => 'exp-panel-test',
    );
    inventoryBloc = InventoryBloc(repository: inventoryRepo);
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(languageCode: 'en'),
      ),
    );
    settingsBloc.add(LoadSettings());
    inventoryBloc.add(LoadInventory());
  });

  tearDown(() {
    expensesBloc.close();
    inventoryBloc.close();
    settingsBloc.close();
  });

  Widget buildPanel() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settingsBloc),
          BlocProvider.value(value: inventoryBloc),
          BlocProvider.value(value: expensesBloc),
        ],
        child: ExpensePanel(user: user),
      ),
    );
  }

  testWidgets('shows expense header and search field', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        LocalizationService().translate('expense.title', languageCode: 'en'),
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('search filters products and tap adds a line', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bre',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    expect(find.text('EGP 15.00'), findsWidgets);
  });

  testWidgets('line list shows qty stepper and remove', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_qty_minus')), findsOneWidget);
    expect(find.byKey(const Key('expense_qty_plus')), findsOneWidget);
    expect(find.byKey(const Key('expense_line_remove')), findsOneWidget);
  });

  testWidgets('new product form adds a draft line', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_new_name')),
      'Olive Oil',
    );
    await tester.enterText(find.byKey(const Key('expense_new_cost')), '60');
    await tester.tap(find.byKey(const Key('expense_new_add')));
    await tester.pumpAndSettle();
    expect(find.text('Olive Oil'), findsWidgets);
  });

  testWidgets('confirm button disabled without lines', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('expense_confirm')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirm dispatches CreateExpense and persists', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense_confirm')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(expensesRepo.expenses.length, 1);
    final saved = expensesRepo.expenses.values.single;
    expect(saved.username, 'cashier1');
    expect(saved.lines.single.barcode, '123');
    expect(saved.totalPiastres, 1500);
    final updated = await inventoryRepo.getInventory();
    Map<String, ProductEntity> updatedMap = {};
    updated.fold((_) => null, (map) => updatedMap = map);
    expect(updatedMap['123']!.stock, 21);
  });

  testWidgets('pre-fills expense name field with auto suggestion', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('expense_name_field')),
    );
    expect(field.controller!.text, 'EXP-00001');
  });

  testWidgets('edited name is dispatched with CreateExpense', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_name_field')),
      'Grocery run',
    );
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense_confirm')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(expensesRepo.expenses.values.single.name, 'Grocery run');
  });

  testWidgets('escape key closes the fullscreen panel', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settingsBloc),
          BlocProvider.value(value: inventoryBloc),
          BlocProvider.value(value: expensesBloc),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        Dialog.fullscreen(child: ExpensePanel(user: user)),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_search_field')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_search_field')), findsNothing);
  });

  testWidgets('confirm button uses accent color', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('expense_confirm')),
    );
    expect(button.style?.backgroundColor?.resolve({}), ExpenseColors.accent);
  });

  testWidgets('tap line qty opens prompt and applies manual value', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense_qty_text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expense_qty_edit_field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('expense_qty_edit_field')),
      '7',
    );
    await tester.tap(find.byKey(const Key('expense_qty_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('cancel qty prompt leaves value unchanged', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_search_field')),
      'Bread',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense_qty_text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_qty_edit_field')),
      '9',
    );
    await tester.tap(find.byKey(const Key('expense_qty_edit_cancel')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('expense_qty_text')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('9'), findsNothing);
  });

  testWidgets('new product qty prompt applies value to draft line', (
    tester,
  ) async {
    await tester.pumpWidget(buildPanel());
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_new_name')),
      'Olive Oil',
    );
    await tester.enterText(find.byKey(const Key('expense_new_cost')), '60');
    await tester.tap(find.byKey(const Key('expense_new_qty_text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense_qty_edit_field')),
      '4',
    );
    await tester.tap(find.byKey(const Key('expense_qty_edit_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense_new_add')));
    await tester.pumpAndSettle();
    expect(find.text('Olive Oil'), findsWidgets);
    expect(find.text('4'), findsOneWidget);
  });
}
