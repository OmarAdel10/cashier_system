// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/app_admin.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;

  setUpAll(() {
    // The T12 gate constructs ApiClient (EnvConfig.apiBaseUrl is a
    // late final - once per process).
    EnvConfig.initializeFromEnv();
  });

  setUp(() {
    firebase = MockFirebaseAuthService();
    admin = MockAdminAuthService();
    when(() => firebase.isSignInWithEmailLink(any())).thenReturn(false);
    // CheckSessionRequested reads the persisted Firebase ID token for the
    // force-revoke fallback (T11 QA).
    when(() => firebase.currentIdToken()).thenAnswer((_) async => null);
    when(
      () => admin.revokeSessions(
        username: any(named: 'username'),
        idToken: any(named: 'idToken'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(() => admin.storedToken()).thenAnswer((_) async => null);
    when(() => admin.storedTenantId()).thenAnswer((_) async => null);
    // Common service stubs shared with the bloc-test setUp (the widget
    // tests below reach states that touch them).
    when(() => admin.clearSession()).thenAnswer((_) async {});
    when(() => admin.savePendingEmail(any())).thenAnswer((_) async {});
    when(() => admin.saveTenantId(any())).thenAnswer((_) async {});
    // T10: _onLogout ends the server-side session before clearing storage.
    when(
      () => admin.logout(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => admin.refreshOwner(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
    when(() => firebase.signOut()).thenAnswer((_) async => const Right(null));
  });

  testWidgets('AdminApp boots into the two-stage login gate', (tester) async {
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    // The injected-bloc path bypasses AdminApp's create-side dispatch —
    // the test drives the event itself.
    bloc.add(const CheckSessionRequested());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is FirebaseStage) break;
    }
    debugPrint('STATE: ${bloc.state}');
    expect(find.text('دفتري — لوحة التحكم'), findsOneWidget);
    expect(find.textContaining('Sign in with Google'), findsOneWidget);
    // No bloc.close() here: closing inside a widget test can deadlock the
    // test isolate's stream sink (flutter_tools FlutterPlatform) — the
    // framework disposes the tree.
  });

  testWidgets('AdminApp carries the ar/en localization delegates', (
    tester,
  ) async {
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    await tester.pumpAndSettle();
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.supportedLocales.length, 2);
    expect(
      material.localizationsDelegates!.contains(
        GlobalMaterialLocalizations.delegate,
      ),
      isTrue,
    );
  });

  testWidgets('CredentialsStage shows the credentials card fields', (
    tester,
  ) async {
    // Plan T11 Step 3: the credentials card shows username/password +
    // تسجيل الدخول (previously untested at the widget level — T11 QA).
    when(() => admin.storedToken()).thenAnswer((_) async => 'jwt-token');
    when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    bloc.add(const CheckSessionRequested());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is CredentialsStage) break;
    }
    expect(bloc.state, isA<CredentialsStage>());
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('A Stage-1 failure returns the user to the Firebase card', (
    tester,
  ) async {
    // T11 QA: FIREBASE_FAILED must render the Firebase card — the old
    // fallback rendered the credentials card, which bounces to Stage 1.
    when(
      () => firebase.signInWithGooglePopup(),
    ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    bloc.add(const GoogleSignInRequested());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is AuthError) break;
    }
    expect(bloc.state, isA<AuthError>());
    expect(find.textContaining('Sign in with Google'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // email field only
  });

  testWidgets('The SESSION_CONFLICT dialog force-revoke dispatches the retry', (
    tester,
  ) async {
    // Plan T11 Step 3: the conflict dialog shows the Arabic message and
    // إلغاء الجلسة الأخرى dispatches ForceRevokeRequested (T11 QA).
    when(() => admin.storedToken()).thenAnswer((_) async => 'jwt-token');
    when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
    var loginCalls = 0;
    when(
      () => admin.credentialLogin(
        tenantId: any(named: 'tenantId'),
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      loginCalls++;
      if (loginCalls == 1) return const Left(SessionConflictFailure('sess-9'));
      return const Right(
        AdminCredentials(
          token: 'jwt-2',
          sessionId: 'sess-10',
          profile: {'tenant_id': 'uid-123'},
        ),
      );
    });
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    // T27: the conflict dialog's retry is widget-supplied through the event
    // (the password stays in the login widget, never in bloc state).
    bloc.add(
      CredentialsSubmitted(
        'admin',
        'pw123456',
        onConflictRetry: () =>
            bloc.add(const ForceRevokeRequested('admin', 'pw123456')),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is SessionConflict) break;
    }
    await tester.pumpAndSettle(); // dialog animation
    expect(find.text('تعارض جلسة'), findsOneWidget);
    expect(find.text('إلغاء الجلسة الأخرى'), findsOneWidget);
    await tester.tap(find.text('إلغاء الجلسة الأخرى'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is AuthAuthenticated) break;
    }
    await tester.pumpAndSettle(); // dialog exit animation
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(find.byType(AlertDialog), findsNothing);
    expect(loginCalls, 2); // conflict attempt + force-revoke retry
  });

  testWidgets('MAGIC_LINK_SENT returns the user to the Firebase card', (
    tester,
  ) async {
    // T11 QA: the magic-link "check your email" info must rerender the
    // Firebase card with the info banner — the credentials card would
    // bounce the user back to Stage 1.
    when(
      () => firebase.sendMagicLink(email: any(named: 'email')),
    ).thenAnswer((_) async => const Right(null));
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    bloc.add(const MagicLinkRequested('owner@daftari.co'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is AuthError) break;
    }
    await tester.pumpAndSettle(); // flush the final frame
    expect(bloc.state, isA<AuthError>());
    expect(
      find.text('تحقق من بريدك الإلكتروني واضغط الرابط لتسجيل الدخول.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sign in with Google'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // the email field only
  });

  testWidgets('AuthLoading renders the loading spinner', (tester) async {
    // T11 QA: the transient AuthLoading state holds a
    // CircularProgressIndicator until the session check resolves.
    final tokenGate = Completer<String?>();
    when(() => firebase.currentIdToken()).thenAnswer((_) => tokenGate.future);
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    bloc.add(const CheckSessionRequested());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    tokenGate.complete(null);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is FirebaseStage) break;
    }
    expect(bloc.state, isA<FirebaseStage>());
  });

  testWidgets('The signed-in card logs out and returns to the Firebase card', (
    tester,
  ) async {
    // T12 gate: AuthAuthenticated swaps to AdminShell (the signed-in card
    // never renders); the shell's AppBar logout returns to Stage 1.
    when(() => admin.storedToken()).thenAnswer((_) async => 'jwt-token');
    when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
    when(
      () => admin.credentialLogin(
        tenantId: any(named: 'tenantId'),
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AdminCredentials(
          token: 'jwt-2',
          sessionId: 'sess-10',
          profile: {'tenant_id': 'uid-123'},
        ),
      ),
    );
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is AuthAuthenticated) break;
    }
    await tester.pumpAndSettle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(find.byType(AdminShell), findsOneWidget);
    // The shell's AppBar logout (tooltip) dispatches LogoutRequested.
    await tester.tap(find.byTooltip('تسجيل الخروج'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is FirebaseStage) break;
    }
    await tester.pumpAndSettle();
    expect(bloc.state, isA<FirebaseStage>());
    expect(find.textContaining('Sign in with Google'), findsOneWidget);
    verify(() => admin.clearSession()).called(1);
    verify(() => firebase.signOut()).called(1);
  });
}
