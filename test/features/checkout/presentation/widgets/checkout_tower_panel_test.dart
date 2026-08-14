import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/core/widgets/section_card.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_tower_panel.dart';
import 'package:cashier_system/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:cashier_system/features/expenses/presentation/expense_panel.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../expenses/helpers/fake_expenses_repository.dart';
import '../../../inventory/helpers/fake_inventory_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> close() async {}
}

Future<void> _pumpPanel(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en'),
    ),
  );
  addTearDown(settingsBloc.close);
  settingsBloc.add(LoadSettings());

  final checkoutBloc = CheckoutBloc();
  addTearDown(checkoutBloc.close);

  final expensesBloc = ExpensesBloc(
    expensesRepo: FakeExpensesRepository(),
    inventoryRepo: FakeInventoryRepository(),
    getCurrentShiftId: () => 's1',
    generateId: () => 'tower-panel-test',
  );
  addTearDown(expensesBloc.close);

  final inventoryBloc = InventoryBloc(repository: FakeInventoryRepository());
  addTearDown(inventoryBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settingsBloc),
            BlocProvider.value(value: checkoutBloc),
            BlocProvider.value(value: inventoryBloc),
            BlocProvider.value(value: expensesBloc),
          ],
          child: CheckoutTowerPanel(
            user: UserEntity(
              username: 'cashier1',
              passwordHash: '',
              role: UserRole.cashier,
              createdAt: DateTime(2026, 8, 11),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  testWidgets(
    'expense pill renders inside cash drawer card with accent color',
    (tester) async {
      await _pumpPanel(tester);

      expect(find.text('Expenses'), findsOneWidget);
      final cashDrawerCard = find.widgetWithText(SectionCard, 'Cash Drawer');
      expect(cashDrawerCard, findsOneWidget);
      final pill = find.descendant(
        of: cashDrawerCard,
        matching: find.byType(OutlinedButton),
      );
      expect(pill, findsOneWidget);
      final button = tester.widget<OutlinedButton>(pill);
      expect(button.style?.foregroundColor?.resolve({}), ExpenseColors.accent);
      expect(button.style?.shape?.resolve({}), isA<StadiumBorder>());
    },
  );

  testWidgets('tapping expense pill opens fullscreen ExpensePanel', (
    tester,
  ) async {
    await _pumpPanel(tester);

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpensePanel), findsOneWidget);
  });
}
