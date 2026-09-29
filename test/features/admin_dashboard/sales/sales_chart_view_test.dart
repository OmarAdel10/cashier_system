// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/sales/sales_chart_view.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    // ApiClient's baseUrl is a late final — once per process.
    EnvConfig.initializeFromEnv();
    // The sales view passes a Map query arg — mocktail needs a fallback.
    registerFallbackValue(<String, String>{});
  });

  final api = MockApiClient();

  testWidgets('SalesChartView renders the fl_chart with 7 points', (
    tester,
  ) async {
    final now = DateTime.now();
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async {
      return Right(<String, dynamic>{
        'ok': true,
        'data': {
          'sales': [
            {
              'id': '1',
              'receipt_json': '{}',
              'total_piastres': 50000,
              'created_at': DateTime(
                now.year,
                now.month,
                now.day - 2,
              ).millisecondsSinceEpoch,
            },
            {
              'id': '2',
              'receipt_json': '{}',
              'total_piastres': 20000,
              'created_at': DateTime(
                now.year,
                now.month,
                now.day - 1,
              ).millisecondsSinceEpoch,
            },
          ],
        },
      });
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SalesChartView(tokenProvider: () async => 'tok', api: api),
      ),
    );
    // Capped real-time pumps: fl_chart's entrance animation + the async
    // load make pumpAndSettle unreliable here.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('مبيعات آخر 7 أيام'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData.single;
    expect(bars.spots, hasLength(7));
    expect(bars.spots[4].y, 50000); // 2 days ago
    expect(bars.spots[5].y, 20000); // yesterday
    expect(bars.spots[6].y, 0); // today zero-filled
    expect(bars.belowBarData.show, isTrue); // the gradient area
  });

  testWidgets('SalesChartView shows the empty state with no sales', (
    tester,
  ) async {
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => const Right(<String, dynamic>{
        'ok': true,
        'data': {'sales': []},
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SalesChartView(tokenProvider: () async => 'tok', api: api),
      ),
    );
    // Capped real-time pumps: fl_chart's entrance animation + the async
    // load make pumpAndSettle unreliable here.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('لا توجد مبيعات في آخر 7 أيام'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets(
    'SalesChartView handles a missing token (empty state, no crash)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SalesChartView(tokenProvider: () async => null, api: api),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LineChart), findsNothing);
    },
  );

  testWidgets(
    'SalesChartView handles a throwing token provider (empty state)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SalesChartView(
            tokenProvider: () async => throw Exception('storage unavailable'),
            api: api,
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The throw must land in the empty state — no spinner, no chart,
      // no unhandled async error.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LineChart), findsNothing);
    },
  );

  testWidgets(
    'the spinner renders while the token fetch is pending, then the chart',
    (tester) async {
      // Deferred tokenProvider (Completer): before it resolves the build
      // shows the spinner (loading=true, buckets=null); after it resolves
      // the chart replaces it — the loading branch is never skipped.
      final gate = Completer<String?>();
      final now = DateTime.now();
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer(
        (_) async => Right(<String, dynamic>{
          'ok': true,
          'data': {
            'sales': [
              {
                'id': '1',
                'receipt_json': '{}',
                'total_piastres': 50000,
                'created_at': DateTime(
                  now.year,
                  now.month,
                  now.day - 1,
                ).millisecondsSinceEpoch,
              },
            ],
          },
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SalesChartView(tokenProvider: () => gate.future, api: api),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete('tok');
      // Capped real-time pumps: fl_chart's entrance animation + the async
      // load make pumpAndSettle unreliable here.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('مبيعات آخر 7 أيام'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    },
  );

  testWidgets(
    'a malformed sales row lands in the empty state (catch path, no crash)',
    (tester) async {
      // A row whose id is not a String throws inside SaleModel.fromJson —
      // the widget-level catch must absorb it into the empty state (never
      // a spinner, never an unhandled async error).
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {
            'sales': [
              {'id': 42, 'total_piastres': 100, 'created_at': 0},
            ],
          },
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SalesChartView(tokenProvider: () async => 'tok', api: api),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('لا توجد مبيعات في آخر 7 أيام'), findsOneWidget);
    },
  );

  testWidgets('the /sales range is requested inclusively of the first day', (
    tester,
  ) async {
    // T27: the api's listSales uses `created_at > since` (strict), so the
    // client must send a boundary strictly before the first bucketed day or
    // a sale at exactly midnight of day-6 is dropped from the chart.
    Map<String, String>? capturedQuery;
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((invocation) async {
      capturedQuery = invocation.namedArguments[#query] as Map<String, String>;
      return const Right(<String, dynamic>{
        'ok': true,
        'data': {'sales': []},
      });
    });
    final now = DateTime.now();
    final boundary = DateTime(
      now.year,
      now.month,
      now.day - 6,
    ).millisecondsSinceEpoch;

    await tester.pumpWidget(
      MaterialApp(
        home: SalesChartView(tokenProvider: () async => 'tok', api: api),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(capturedQuery, isNotNull);
    expect(int.parse(capturedQuery!['since']!), lessThan(boundary));
  });

  testWidgets('the chart data is memoized across rebuilds', (tester) async {
    // T27: _chartData must not be rebuilt on every frame (an unrelated
    // setState/parent rebuild reused the same LineChartData instance).
    final now = DateTime.now();
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => Right(<String, dynamic>{
        'ok': true,
        'data': {
          'sales': [
            {
              'id': '1',
              'receipt_json': '{}',
              'total_piastres': 50000,
              'created_at': DateTime(
                now.year,
                now.month,
                now.day - 1,
              ).millisecondsSinceEpoch,
            },
          ],
        },
      }),
    );

    Widget build() => MaterialApp(
      home: SalesChartView(tokenProvider: () async => 'tok', api: api),
    );

    await tester.pumpWidget(build());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final before = tester.widget<LineChart>(find.byType(LineChart)).data;

    // A fresh widget instance with the same key rebuilds the State's build
    // without re-running _load (initState is not called again).
    await tester.pumpWidget(build());
    await tester.pump();
    final after = tester.widget<LineChart>(find.byType(LineChart)).data;

    expect(identical(before, after), isTrue);
  });
}
