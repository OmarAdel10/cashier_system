import 'package:cashier_system/core/theme/app_theme.dart';
import 'package:cashier_system/features/sales/presentation/widgets/summary_bar.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(SummaryBar bar) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: bar),
    );
  }

  testWidgets('shows profit and margin for today and monthly', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 200000,
          receiptCount: 3,
          itemsSold: 10,
          profitPiastres: 50000,
          monthlyOrderCount: 30,
          monthlyTotalPiastres: 2000000,
          monthlyItemsSold: 100,
          monthlyProfitPiastres: 800000,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    expect(find.text('Profit'), findsNWidgets(2));
    expect(find.text('EGP 500.00'), findsOneWidget);
    expect(find.text('EGP 8000.00'), findsOneWidget);
    expect(find.text('Margin: 25.0%'), findsOneWidget);
    expect(find.text('Margin: 40.0%'), findsOneWidget);
  });

  testWidgets('shows zero profit and margin when revenue is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 0,
          receiptCount: 0,
          itemsSold: 0,
          profitPiastres: 0,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    expect(find.text('Profit'), findsNWidgets(2));
    expect(find.text('Margin: 0.0%'), findsNWidgets(2));
  });

  testWidgets('shows negative margin when costs exceed revenue', (
    tester,
  ) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 100000,
          receiptCount: 1,
          itemsSold: 1,
          profitPiastres: -20000,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    expect(find.text('-20.0%'), findsNothing);
    expect(find.text('Margin: -20.0%'), findsOneWidget);
  });
}
