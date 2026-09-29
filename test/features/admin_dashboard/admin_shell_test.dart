// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/dashboard_bloc.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    EnvConfig.initializeFromEnv();
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient api;

  setUp(() {
    api = MockApiClient();
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
  });

  Widget shell({bool isOwner = false}) {
    // No tokenProvider → the shell's `?? () async => null` fallback runs;
    // the users/subscription token-null paths stay network-free.
    return MaterialApp(
      home: BlocProvider<DashboardBloc>(
        create: (_) =>
            DashboardBloc(api: api, tokenProvider: () async => 'tok'),
        child: AdminShell(isOwner: isOwner),
      ),
    );
  }

  testWidgets('the users destination wires UsersView (T14)', (tester) async {
    await tester.pumpWidget(shell());
    await tester.pump(); // the shell frame (the overview spinner runs)
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pump(); // the UsersBloc's null-token guard fires
    await tester.pump(const Duration(seconds: 1)); // the SnackBar entrance
    // The fallback token (null) → the session-expired error; the
    // BlocConsumer listener shows a SnackBar, the builder the center.
    expect(find.text('انتهت الجلسة. سجل الدخول من جديد.'), findsWidgets);
  });

  testWidgets('the subscription destination wires SubscriptionView (T14)', (
    tester,
  ) async {
    await tester.pumpWidget(shell());
    await tester.pump(); // the shell frame (the overview spinner runs)
    await tester.tap(find.byIcon(Icons.workspace_premium_outlined));
    await tester.pump(); // the tokenProvider resolves → the error state
    await tester.pump();
    expect(find.text('انتهت الجلسة. سجل الدخول من جديد.'), findsOneWidget);
  });

  testWidgets('a DashboardState change does not rebuild the shell chrome', (
    tester,
  ) async {
    // T27: the BlocBuilder is scoped to the content pane — a dashboard
    // update must not recreate the nav rail (or the Scaffold).
    await tester.pumpWidget(shell());
    await tester.pump();
    final before = tester.widget<NavigationRail>(find.byType(NavigationRail));
    final bloc = BlocProvider.of<DashboardBloc>(
      tester.element(find.byType(AdminShell)),
    );
    bloc.add(const OverviewRequested());
    await tester.pump();
    await tester.pump();
    final after = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(identical(before, after), isTrue);
  });
}
