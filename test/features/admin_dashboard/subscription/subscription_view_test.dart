// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/subscription/subscription_view.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    EnvConfig.initializeFromEnv();
  });

  late MockApiClient api;

  setUp(() {
    api = MockApiClient();
  });

  testWidgets('SubscriptionView renders the tier + the upgrade dialog', (
    tester,
  ) async {
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((inv) {
      final path = inv.positionalArguments[0] as String;
      return switch (path) {
        '/auth/me' => Future.value(
          const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'profile': {'tier': 'pro'},
            },
          }),
        ),
        _ => Future.value(
          const Right(<String, dynamic>{
            'ok': true,
            'data': {'active_sessions': 2},
          }),
        ),
      };
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionView(tokenProvider: () async => 'tok', api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المحترف (Professional)'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('ترقية الباقة'));
    await tester.pumpAndSettle();
    expect(find.text('ترقية الباقة'), findsWidgets); // dialog title + button
    expect(find.textContaining('Paymob'), findsOneWidget);
  });

  testWidgets('SubscriptionView shows the error with a failed fetch', (
    tester,
  ) async {
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenThrow(StateError('down'));

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionView(tokenProvider: () async => 'tok', api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('فشل تحميل بيانات الاشتراك.'), findsOneWidget);
  });

  testWidgets('a null token shows the session-expired error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionView(tokenProvider: () async => null, api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('انتهت الجلسة. سجل الدخول من جديد.'), findsOneWidget);
    // The guard fires before any api call is attempted.
    verifyNever(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    );
  });
}
