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

  testWidgets('shows totals for today and monthly', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 200000,
          receiptCount: 3,
          itemsSold: 10,
          monthlyOrderCount: 30,
          monthlyTotalPiastres: 2000000,
          monthlyItemsSold: 100,
          todayExpensesPiastres: 0,
          monthlyExpensesPiastres: 0,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    expect(find.text('EGP 2000.00'), findsOneWidget);
    expect(find.text('EGP 20000.00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('shows zero totals when nothing was sold', (tester) async {
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 0,
          receiptCount: 0,
          itemsSold: 0,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    expect(find.text('EGP 0.00'), findsNWidgets(4));
    expect(find.text('0'), findsNWidgets(4));
  });

  testWidgets('all metric cards in a row have equal heights', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(
      wrap(
        SummaryBar(
          totalPiastres: 200000,
          receiptCount: 3,
          itemsSold: 10,
          monthlyOrderCount: 30,
          monthlyTotalPiastres: 2000000,
          monthlyItemsSold: 100,
          todayExpensesPiastres: 5000,
          monthlyExpensesPiastres: 50000,
          langCode: 'en',
          t: LocalizationService(),
        ),
      ),
    );

    final cards = tester
        .widgetList<MetricCard>(find.byType(MetricCard))
        .map((card) => tester.getSize(find.byWidget(card)).height)
        .toList();
    expect(cards.length, 8);
    expect(cards.take(3).toSet().length, 1, reason: 'daily left: $cards');
    expect(
      cards.skip(4).take(3).toSet().length,
      1,
      reason: 'monthly left: $cards',
    );
  });
}
