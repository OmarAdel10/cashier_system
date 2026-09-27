// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/app_admin.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;

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
    bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
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
}
