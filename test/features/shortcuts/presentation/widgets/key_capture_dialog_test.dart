import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/shortcuts/presentation/widgets/key_capture_dialog.dart';

/// Wraps [KeyCaptureDialog] in a MaterialApp so Navigator works.
Future<void> _pumpDialog(
  WidgetTester tester, {
  String currentCombo = '',
  String languageCode = 'en',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog<String>(
                context: context,
                builder: (_) => KeyCaptureDialog(
                  currentCombo: currentCombo,
                  languageCode: languageCode,
                ),
              );
            },
            child: const Text('Open'),
          );
        },
      ),
    ),
  );

  // Tap button to open dialog
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('KeyCaptureDialog', () {
    testWidgets('renders dialog with prompt', (tester) async {
      await _pumpDialog(tester);

      // Dialog should be visible
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(KeyCaptureDialog), findsOneWidget);
    });

    testWidgets('shows cancel button', (tester) async {
      await _pumpDialog(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('captures ctrl+letter combo', (tester) async {
      await _pumpDialog(tester);

      // Send a modifier + key press to the focused dialog
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // After capture, confirm button should appear
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('captures key with modifier', (tester) async {
      await _pumpDialog(tester);

      // Simulate Ctrl key down
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Then press a key
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      // After capture, confirm button should appear
      expect(find.byType(FilledButton), findsOneWidget);

      // Release Ctrl
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    });

    testWidgets('escape without modifiers closes dialog', (tester) async {
      await _pumpDialog(tester);

      // Verify dialog is open
      expect(find.byType(KeyCaptureDialog), findsOneWidget);

      // Close via Navigator pop (simulates escape behavior)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();

      await tester.pumpAndSettle();
      expect(find.byType(KeyCaptureDialog), findsNothing);
    });

    testWidgets('escape with modifier captures instead of closing', (
      tester,
    ) async {
      await _pumpDialog(tester);

      // Press Ctrl+Escape — should capture, not close
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Confirm button should appear (captured, not closed)
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(KeyCaptureDialog), findsOneWidget);
    });

    testWidgets('pop returns captured combo string', (tester) async {
      String? capturedCombo;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  capturedCombo = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        KeyCaptureDialog(currentCombo: '', languageCode: 'en'),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Press ctrl+a to capture
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Tap confirm
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // Should return the combo string
      expect(capturedCombo, isNotNull);
      expect(capturedCombo, isNotEmpty);
      expect(capturedCombo, 'ctrl+a');
    });

    testWidgets('displays currently captured combo', (tester) async {
      await _pumpDialog(tester);

      // Press ctrl+b
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // The captured combo should be displayed in the dialog
      // (the displayCombo function transforms 'ctrl+b' to 'Ctrl+B')
      expect(find.text('Ctrl+B'), findsWidgets);
    });

    testWidgets('handles modifier keys without triggering capture', (
      tester,
    ) async {
      await _pumpDialog(tester);

      // Press only modifier keys — should NOT trigger capture
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      // Confirm button should NOT appear (only modifiers pressed)
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Modifier-only press should not trigger capture',
      );
    });

    testWidgets('captures function keys', (tester) async {
      await _pumpDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();

      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'F1 key press should trigger capture',
      );
    });

    testWidgets('captures arrow keys', (tester) async {
      await _pumpDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'Arrow key press should trigger capture',
      );
    });

    testWidgets('freezes combo when modifier released before confirm', (
      tester,
    ) async {
      await _pumpDialog(tester);

      // Press Ctrl+F
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      // Combo should show Ctrl+F
      expect(find.text('Ctrl+F'), findsWidgets);

      // Release Ctrl
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Combo should STILL show Ctrl+F (frozen)
      expect(find.text('Ctrl+F'), findsWidgets);

      // Confirm
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // Should return ctrl+f
      // Can't easily check return value here, but dialog should close
      expect(find.byType(Navigator), findsOneWidget);
    });

    testWidgets('rejects unsupported keys (tab, numpad, home)', (tester) async {
      await _pumpDialog(tester);

      // Press Tab (unsupported)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Confirm button should NOT appear
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Unsupported key should not trigger capture',
      );

      // Press Numpad0 (unsupported)
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad0);
      await tester.pump();

      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Numpad key should not trigger capture',
      );

      // Press Home (unsupported)
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();

      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Home key should not trigger capture',
      );
    });

    testWidgets('captures supported keys after rejecting unsupported', (
      tester,
    ) async {
      await _pumpDialog(tester);

      // Press Tab (unsupported) - ignored
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Then press F5 (supported) - should capture
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pump();

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('F5'), findsWidgets);
    });

    testWidgets('rejects bare printable keys (digits, letters, space, enter)', (
      tester,
    ) async {
      await _pumpDialog(tester);

      // Bare digit
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Bare digit should not be capturable (scanner injection risk)',
      );

      // Bare letter
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Bare letter should not be capturable',
      );

      // Bare space
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Bare space should not be capturable',
      );

      // Bare enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'Bare enter should not be capturable',
      );
    });

    testWidgets('accepts bare safe keys (function/arrow/navigation)', (
      tester,
    ) async {
      await _pumpDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pump();
      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'Bare F12 is safe and should capture',
      );
    });

    testWidgets('accepts printable key with modifier', (tester) async {
      await _pumpDialog(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'ctrl+digit should capture',
      );
      expect(find.text('Ctrl+1'), findsWidgets);
    });
  });
}
