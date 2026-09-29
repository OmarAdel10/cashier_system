// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';
import 'package:cashier_system/features/admin_dashboard/login/login_screen.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;

  setUpAll(() {
    EnvConfig.initializeFromEnv();
  });

  setUp(() {
    firebase = MockFirebaseAuthService();
    admin = MockAdminAuthService();
    when(() => admin.storedToken()).thenAnswer((_) async => null);
    when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
    when(() => admin.clearSession()).thenAnswer((_) async {});
    when(() => admin.saveTenantId(any())).thenAnswer((_) async {});
    when(
      () => admin.refreshOwner(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
  });

  /// [code] forced as the credential-login failure.
  Future<void> pumpErrorCode(WidgetTester tester, String code) async {
    when(
      () => admin.credentialLogin(
        tenantId: any(named: 'tenantId'),
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Left(AdminAuthFailure(code)));
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AdminAuthBloc>.value(
          value: bloc,
          child: const LoginScreen(),
        ),
      ),
    );
    bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is AuthError) break;
    }
    expect(bloc.state, isA<AuthError>());
  }

  group('AuthError → stage routing', () {
    for (final code in const [
      'OWNER_REAUTH_REQUIRED',
      'SESSION_STALE',
      'SESSION_REVOKED',
      'SESSION_EXPIRED',
    ]) {
      testWidgets('$code renders the Firebase card, not the credentials card', (
        tester,
      ) async {
        await pumpErrorCode(tester, code);
        await tester.pumpAndSettle();
        // The owner re-auth must land on the Google / magic-link card; the
        // credentials card was the old dead end (T11/T27).
        expect(find.textContaining('Sign in with Google'), findsOneWidget);
        expect(find.text('تسجيل الدخول'), findsNothing);
        expect(find.byType(TextField), findsOneWidget); // the email field only
      });
    }

    testWidgets('BAD_CREDENTIALS still renders the credentials card', (
      tester,
    ) async {
      await pumpErrorCode(tester, 'BAD_CREDENTIALS');
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign in with Google'), findsNothing);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });
}
