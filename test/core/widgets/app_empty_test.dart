import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/widgets/app_empty.dart';

void main() {
  group('AppEmpty', () {
    testWidgets('renders default state with PhosphorIcon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppEmpty())),
      );

      expect(find.byType(PhosphorIcon), findsOneWidget);
    });

    testWidgets('renders headline when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmpty(headline: 'No items')),
        ),
      );

      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('renders body when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppEmpty(body: 'Nothing to show')),
        ),
      );

      expect(find.text('Nothing to show'), findsOneWidget);
    });

    testWidgets('renders headline and body together', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(headline: 'Empty', body: 'No data available'),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('renders custom action widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmpty(
              headline: 'Empty',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(icon: PhosphorIcons.receiptDuotone),
          ),
        ),
      );

      expect(find.byType(PhosphorIcon), findsOneWidget);
    });

    testWidgets('no parameters renders only default icon without text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppEmpty())),
      );

      expect(find.byType(PhosphorIcon), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });
}
