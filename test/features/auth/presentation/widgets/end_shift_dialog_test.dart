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
                builder: (_) => const EndShiftDialog(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('End Shift'), findsWidgets);
      expect(find.text('Are you sure you want to end your shift?'), findsOneWidget);
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
                  builder: (_) => const EndShiftDialog(),
                ) ?? false;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End Shift'));
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
                  builder: (_) => const EndShiftDialog(),
                ) ?? true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
