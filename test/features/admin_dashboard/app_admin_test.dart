// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/app_admin.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';
import 'package:cashier_system/features/admin_dashboard/login/login_screen.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

String _liveJwt() {
  String seg(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600, 'tid': 'tenant-1', 'usr': 'boss', 'role': 'admin', 'jti': 'sess-1'})}.sig';
}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;

  setUpAll(() {
    EnvConfig.initializeFromEnv();
  });

  setUp(() {
    firebase = MockFirebaseAuthService();
    admin = MockAdminAuthService();
    when(() => firebase.isSignInWithEmailLink(any())).thenReturn(false);
    when(() => firebase.currentIdToken()).thenAnswer((_) async => null);
    when(() => firebase.tenantId).thenReturn('tenant-1');
    when(() => firebase.signOut()).thenAnswer((_) async => const Right(null));
    when(() => admin.storedToken()).thenAnswer((_) async => null);
    when(() => admin.storedTenantId()).thenAnswer((_) async => null);
    when(() => admin.pendingMagicEmail()).thenAnswer((_) async => null);
    when(() => admin.validToken()).thenAnswer((_) async => null);
    when(() => admin.clearSession()).thenAnswer((_) async {});
    when(() => admin.saveTenantId(any())).thenAnswer((_) async {});
    when(
      () => admin.refreshOwner(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => admin.logout(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
  });

  testWidgets('an unsupported locale resolves to English, not Arabic', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.binding.platformDispatcher.clearAllTestValues);
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(LoginScreen));
    expect(Localizations.localeOf(context).languageCode, 'en');
    expect(Directionality.of(context), TextDirection.ltr);
  });

  testWidgets('the session token provider fetches the stored JWT live', (
    tester,
  ) async {
    final token = _liveJwt();
    when(() => admin.storedToken()).thenAnswer((_) async => token);
    when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
    when(() => admin.resumeSession(idToken: any(named: 'idToken'))).thenAnswer(
      (_) async => const Right(
        SessionResume(
          token: 'fresh-jwt',
          sessionId: 'sess-2',
          profile: {'username': 'boss'},
        ),
      ),
    );
    var live = 'session-1';
    when(() => admin.validToken()).thenAnswer((_) async => live);

    await tester.pumpWidget(
      AdminApp(adminService: admin, firebaseService: firebase),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(AdminShell).evaluate().isNotEmpty) break;
    }
    final shell = tester.widget<AdminShell>(find.byType(AdminShell));
    expect(await shell.tokenProvider!(), 'session-1');
    live = 'session-2';
    expect(await shell.tokenProvider!(), 'session-2');
    // Unmount so the authenticated shell's realtime socket is closed before
    // the test teardown (a pending connect timer would fail the test).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'the owner token provider returns the refreshed Firebase ID token',
    (tester) async {
      final credential = MockUserCredential();
      final user = MockUser();
      when(() => credential.user).thenReturn(user);
      when(() => user.email).thenReturn('owner@daftari.co');
      when(
        () => firebase.signInWithGooglePopup(),
      ).thenAnswer((_) async => Right(credential));
      var idToken = 'owner-token-1';
      when(() => firebase.currentIdToken()).thenAnswer((_) async => idToken);
      when(
        () => admin.tenantAccounts(idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(
        AdminApp(adminService: admin, firebaseService: firebase),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.textContaining('Sign in with Google').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.tap(find.textContaining('Sign in with Google'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(AdminShell).evaluate().isNotEmpty) break;
      }
      final shell = tester.widget<AdminShell>(find.byType(AdminShell));
      expect(await shell.tokenProvider!(), 'owner-token-1');
      idToken = 'owner-token-2';
      expect(await shell.tokenProvider!(), 'owner-token-2');
      // Unmount so the authenticated shell's realtime socket is closed before
      // the test teardown (a pending connect timer would fail the test).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
