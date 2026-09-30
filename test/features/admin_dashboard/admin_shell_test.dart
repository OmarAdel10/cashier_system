// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/dashboard_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';
import 'package:cashier_system/features/admin_dashboard/login/login_screen.dart';
import 'package:cashier_system/features/admin_dashboard/overview/overview_view.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

String _liveJwt() {
  String seg(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600, 'tid': 'tenant-1', 'usr': 'boss', 'role': 'admin', 'jti': 'sess-1'})}.sig';
}

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

  testWidgets(
    'a 401 from /admin/overview routes the user to the Firebase stage',
    (tester) async {
      // T28: the failed dashboard request must dispatch the session-expired
      // event, which lands the admin on the Firebase re-auth card via
      // AuthError(code: 'SESSION_EXPIRED') — not a dead dashboard screen.
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[0] as String;
        if (path == '/admin/overview') {
          return const Left(HttpFailure(401, '/admin/overview'));
        }
        return const Left(DatabaseFailure('down'));
      });

      final firebase = MockFirebaseAuthService();
      final admin = MockAdminAuthService();
      when(() => firebase.isSignInWithEmailLink(any())).thenReturn(false);
      when(() => firebase.currentIdToken()).thenAnswer((_) async => null);
      when(() => admin.storedToken()).thenAnswer((_) async => _liveJwt());
      when(() => admin.clearSession()).thenAnswer((_) async {});
      when(
        () => admin.resumeSession(idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right(
          SessionResume(
            token: 'fresh-jwt',
            sessionId: 'sess-2',
            profile: <String, dynamic>{'username': 'boss'},
          ),
        ),
      );

      final auth = AdminAuthBloc(firebase: firebase, admin: admin);
      auth.add(const CheckSessionRequested());
      addTearDown(auth.close);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: BlocProvider<AdminAuthBloc>.value(
            value: auth,
            child: BlocBuilder<AdminAuthBloc, AdminAuthState>(
              builder: (context, state) => state is AuthAuthenticated
                  ? BlocProvider<DashboardBloc>(
                      create: (_) => DashboardBloc(
                        api: api,
                        tokenProvider: () async => 'tok',
                      )..add(const OverviewRequested()),
                      child: const AdminShell(),
                    )
                  : const LoginScreen(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.textContaining('Sign in with Google').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(auth.state, isA<AuthError>());
      expect((auth.state as AuthError).code, 'SESSION_EXPIRED');
      expect(find.textContaining('Sign in with Google'), findsOneWidget);
      expect(find.byType(OverviewView), findsNothing);
    },
  );
}
