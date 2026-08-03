import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/presentation/widgets/end_shift_dialog.dart';

void main() {
  group('EndShiftDialog', () {
    testWidgets('shows title and confirmation message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const EndShiftDialog(langCode: 'ar'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('إنهاء الوردية'), findsWidgets);
      expect(find.text('هل أنت متأكد من إنهاء الوردية؟'), findsOneWidget);
    });

    testWidgets('pops true on confirm', (tester) async {
      var result = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const EndShiftDialog(langCode: 'ar'),
                ) ?? false;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'إنهاء الوردية'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('pops false on cancel', (tester) async {
      var result = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const EndShiftDialog(langCode: 'ar'),
                ) ?? true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
