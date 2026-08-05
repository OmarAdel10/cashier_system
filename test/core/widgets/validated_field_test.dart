import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/widgets/validated_field.dart';

void main() {
  group('ValidatedField', () {
    testWidgets('renders label text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedField(
              controller: controller,
              label: 'Username',
              hint: 'Enter username',
              rules: [],
            ),
          ),
        ),
      );
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter username'), findsOneWidget);
      controller.dispose();
    });

    testWidgets(
      'shows validation error on focus loss for empty required field',
      (tester) async {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValidatedField(
                controller: controller,
                label: 'Username',
                hint: 'Enter username',
                focusNode: focusNode,
                rules: [
                  ValidatedFieldRule(
                    message: 'Username is required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(find.text('Username is required'), findsOneWidget);
      },
    );

    testWidgets('shows valid state when field passes validation', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'valid');
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedField(
              controller: controller,
              label: 'Username',
              hint: 'Enter username',
              focusNode: focusNode,
              rules: [
                ValidatedFieldRule(
                  message: 'Username is required',
                  isValid: (v) => v.trim().isNotEmpty,
                ),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Enter username'), findsOneWidget);
    });

    testWidgets('calls onLastFieldSubmit when valid and isLast on submit', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'valid');
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedField(
              controller: controller,
              label: 'Field',
              hint: 'hint',
              rules: [
                ValidatedFieldRule(
                  message: 'Required',
                  isValid: (v) => v.trim().isNotEmpty,
                ),
              ],
              isLast: true,
              onLastFieldSubmit: () => submitted = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
      controller.dispose();
    });

    testWidgets('does not call onLastFieldSubmit when invalid on submit', (
      tester,
    ) async {
      final controller = TextEditingController();
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedField(
              controller: controller,
              label: 'Field',
              hint: 'hint',
              rules: [
                ValidatedFieldRule(
                  message: 'Required',
                  isValid: (v) => v.trim().isNotEmpty,
                ),
              ],
              isLast: true,
              onLastFieldSubmit: () => submitted = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      controller.dispose();
    });

    testWidgets('shows hint text by default', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValidatedField(
              controller: controller,
              label: 'Field',
              hint: 'Type something',
              rules: [],
            ),
          ),
        ),
      );
      expect(find.text('Type something'), findsOneWidget);
      controller.dispose();
    });
  });
}
