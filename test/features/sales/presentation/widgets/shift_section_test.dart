import 'package:cashier_system/core/error/receipt_status.dart';
import 'package:cashier_system/core/theme/app_theme.dart';
import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import 'package:cashier_system/features/sales/presentation/widgets/shift_section.dart';
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

ShiftGroup _shift(List<ReceiptEntity> receipts) {
  return ShiftGroup(
    shiftId: 's1',
    startedAt: DateTime(2026, 8, 1, 9, 0),
    endedAt: DateTime(2026, 8, 1, 17, 0),
    receipts: receipts,
  );
}

bool _hasAccentColor(Text t) => t.style?.color == ExpenseColors.accent;

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(ShiftGroup shift) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ShiftSection(
          shiftGroup: shift,
          user: _user,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );
  }

  testWidgets('shows expense amount in accent color when expenses exist', (
    tester,
  ) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        _shift([
          _receipt(id: 's1', total: 20000),
          _receipt(id: 'e1', total: 5000, status: ReceiptStatus.expense),
        ]),
      ),
    );

    final text = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('EGP 50.00'),
      ),
    );
    expect(text.style?.color, ExpenseColors.accent);
    expect(_hasAccentColor(text), isTrue);
  });

  testWidgets('hides expense amount when no expenses exist', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(wrap(_shift([_receipt(id: 's1', total: 20000)])));

    expect(find.textContaining('EGP 50.00'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Text && _hasAccentColor(w)),
      findsNothing,
    );
  });
}
