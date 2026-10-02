// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/admin_dashboard/dashboard/models.dart';
import 'package:cashier_system/features/admin_dashboard/overview/overview_view.dart';

void main() {
  testWidgets('the stat card accent border follows the text direction', (
    tester,
  ) async {
    // T27: a physical `Border(left:)` keeps pointing at the physical left in
    // RTL; `BorderDirectional(start:)` mirrors with the locale.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: QuickStatsRow(
              stats: OverviewStats(
                saleCount: 3,
                totalPiastres: 1000,
                activeSessions: 1,
                devicesOnline: 2,
                alerts: 0,
              ),
            ),
          ),
        ),
      ),
    );

    final bordered = tester.widgetList<Container>(find.byType(Container)).where(
      (c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.border != null;
      },
    ).toList();
    expect(bordered, isNotEmpty);
    for (final container in bordered) {
      expect(
        (container.decoration! as BoxDecoration).border,
        isA<BorderDirectional>(),
      );
    }
  });
}
