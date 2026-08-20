import 'package:cashier_system/core/theme/app_theme.dart';
import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import 'package:cashier_system/features/sales/presentation/widgets/month_card.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _user = UserEntity(
  username: 'admin',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.admin,
  createdAt: DateTime(2026, 1, 1),
);

MonthGroupedData _month({
  int receiptCount = 0,
  int expenseCount = 0,
  List<DayGroup> days = const [],
}) {
  return MonthGroupedData(
    year: 2026,
    month: 8,
    totalPiastres: 20000,
    receiptCount: receiptCount,
    expenseCount: expenseCount,
    days: days,
  );
}

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(MonthGroupedData? md) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MonthCard(
          year: 2026,
          month: 8,
          monthData: md,
          isLoading: false,
          user: _user,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );
  }

  testWidgets('shows red expense count and amount when expenses exist', (
    tester,
  ) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        _month(
          receiptCount: 1,
          expenseCount: 1,
          days: [DayGroup(date: DateTime(2026, 8, 1), expensesPiastres: 5000)],
        ),
      ),
    );

    expect(find.text('1 Receipt'), findsOneWidget);

    final countText = tester.widget<Text>(find.text('1 Expense'));
    expect(countText.style?.color, ExpenseColors.accent);
    expect(countText.style?.fontSize, TextStyles.body.fontSize);

    final amountText = tester.widget<Text>(find.text('EGP 50.00'));
    expect(amountText.style?.color, ExpenseColors.accent);
    expect(amountText.style?.fontSize, TextStyles.title.fontSize);
  });

  testWidgets('hides red expense text when no expenses exist', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(wrap(_month(receiptCount: 1, days: const [])));

    expect(find.text('1 Expense'), findsNothing);
    expect(find.text('EGP 50.00'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.style?.color == ExpenseColors.accent,
      ),
      findsNothing,
    );
  });

  testWidgets('renders singular Receipt label for one receipt', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(wrap(_month(receiptCount: 1)));

    expect(find.text('1 Receipt'), findsOneWidget);
  });
}
