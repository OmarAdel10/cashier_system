import 'package:cashier_system/core/error/receipt_status.dart';
import 'package:cashier_system/core/theme/app_theme.dart';
import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import 'package:cashier_system/features/sales/presentation/widgets/day_section.dart';
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

ReceiptEntity _receipt({
  required String id,
  required int total,
  ReceiptStatus status = ReceiptStatus.active,
}) {
  return ReceiptEntity(
    id: id,
    shiftId: 's1',
    orderNumber: 'R-$id',
    items: const [],
    subtotalPiastres: total,
    totalPiastres: total,
    createdAt: DateTime(2026, 8, 1, 9, 0),
    username: 'cashier1',
    status: status,
  );
}

DayGroup _day({
  required int expensesPiastres,
  List<ReceiptEntity> receipts = const [],
}) {
  return DayGroup(
    date: DateTime(2026, 8, 1),
    expensesPiastres: expensesPiastres,
    cashiers: [
      CashierDayGroup(
        username: 'cashier1',
        shifts: [
          ShiftGroup(
            shiftId: 's1',
            startedAt: DateTime(2026, 8, 1, 9, 0),
            endedAt: DateTime(2026, 8, 1, 17, 0),
            receipts: receipts,
          ),
        ],
      ),
    ],
  );
}

String _plainText(Text t) => t.data ?? t.textSpan?.toPlainText() ?? '';

bool _hasAccentColor(Text t) {
  if (t.style?.color == ExpenseColors.accent) return true;
  final root = t.textSpan;
  if (root == null) return false;
  final stack = <InlineSpan>[root];
  while (stack.isNotEmpty) {
    final span = stack.removeLast();
    if (span is TextSpan && span.style?.color == ExpenseColors.accent)
      return true;
    if (span is TextSpan) stack.addAll(span.children ?? const []);
  }
  return false;
}

Finder _accentText(String needle) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.textSpan != null &&
      _plainText(w).contains(needle) &&
      _hasAccentColor(w),
);

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(DayGroup day) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DaySection(
          day: day,
          user: _user,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );
  }

  testWidgets('shows expense segment in accent color when day has expenses', (
    tester,
  ) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        _day(
          expensesPiastres: 5000,
          receipts: [
            _receipt(id: 'e1', total: 5000, status: ReceiptStatus.expense),
          ],
        ),
      ),
    );

    expect(_accentText('EGP 50.00'), findsOneWidget);
    expect(_accentText('1 Expense'), findsOneWidget);
  });

  testWidgets('hides expense segment when day has no expenses', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(wrap(_day(expensesPiastres: 0)));

    expect(find.textContaining('Expense'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Text && _hasAccentColor(w)),
      findsNothing,
    );
  });

  testWidgets('renders singular Receipt label for one sales receipt', (
    tester,
  ) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        _day(expensesPiastres: 0, receipts: [_receipt(id: 's1', total: 5000)]),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (w) => w is Text && _plainText(w).contains('1 Receipt'),
      ),
      findsOneWidget,
    );
  });
}
