// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;
  late MockUserCredential credential;
  late MockUser user;

  setUpAll(() {
    registerFallbackValue(const AdminAuthFailure('fallback'));
  });

  setUp(() {
    firebase = MockFirebaseAuthService();
    admin = MockAdminAuthService();
    credential = MockUserCredential();
    user = MockUser();

    when(() => credential.user).thenReturn(user);
    when(() => user.email).thenReturn('owner@daftari.co');
    when(
      () => firebase.signInWithGooglePopup(),
    ).thenAnswer((_) async => Right(credential));
    when(
      () => firebase.signInWithEmailLink(
        email: any(named: 'email'),
        link: any(named: 'link'),
      ),
    ).thenAnswer((_) async => Right(credential));
    when(() => firebase.isSignInWithEmailLink(any())).thenReturn(false);
    when(
      () => firebase.currentIdToken(),
    ).thenAnswer((_) async => 'firebase-id-token');
    when(() => firebase.tenantId).thenReturn('tenant-1');
    when(() => firebase.signOut()).thenAnswer((_) async => const Right(null));
    when(
      () => firebase.sendMagicLink(email: any(named: 'email')),
    ).thenAnswer((_) async => const Right(null));

    when(
      () => admin.refreshOwner(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => admin.revokeSessions(
        username: any(named: 'username'),
        idToken: any(named: 'idToken'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(() => admin.clearSession()).thenAnswer((_) async {});
    when(() => admin.savePendingEmail(any())).thenAnswer((_) async {});
  });

  AdminAuthBloc makeBloc() => AdminAuthBloc(firebase: firebase, admin: admin);

  group('CheckSessionRequested', () {
    test('stored token + tenant → CredentialsStage (tenant known)', () async {
      when(() => admin.storedToken()).thenAnswer((_) async => 'jwt-token');
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CheckSessionRequested());
      await bloc.stream.firstWhere((s) => s is CredentialsStage);
      expect(states.first, isA<AuthLoading>());
      expect(states.last, isA<CredentialsStage>());
      await sub.cancel();
      await bloc.close();
    });

    test('nothing stored → FirebaseStage', () async {
      when(() => admin.storedToken()).thenAnswer((_) async => null);
      when(() => admin.storedTenantId()).thenAnswer((_) async => null);
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CheckSessionRequested());
      await bloc.stream.firstWhere((s) => s is FirebaseStage);
      expect(states.last, isA<FirebaseStage>());
      await sub.cancel();
      await bloc.close();
    });
  });

  group('Firebase stage (Google)', () {
    test('success with existing accounts → CredentialsStage', () async {
      when(
        () => admin.tenantAccounts(idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => Right([
          {'username': 'boss'},
        ]),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((s) => s is CredentialsStage);
      verify(() => admin.refreshOwner(idToken: 'firebase-id-token')).called(1);
      expect(states.last, isA<CredentialsStage>());
      await sub.cancel();
      await bloc.close();
    });

    test(
      'success with EMPTY accounts → first-admin bootstrap (owner direct)',
      () async {
        when(
          () => admin.tenantAccounts(idToken: any(named: 'idToken')),
        ).thenAnswer((_) async => const Right([]));
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        final state = states.last as AuthAuthenticated;
        expect(state.isOwner, isTrue);
        expect(state.token, 'firebase-id-token');
        await sub.cancel();
        await bloc.close();
      },
    );

    test('Firebase failure → AuthError', () async {
      when(
        () => firebase.signInWithGooglePopup(),
      ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'FIREBASE_FAILED');
      expect(state.messageAr, isNotEmpty);
      await sub.cancel();
      await bloc.close();
    });
  });

  group('Magic link', () {
    test('MagicLinkRequested sends the link → MAGIC_LINK_SENT info', () async {
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const MagicLinkRequested('owner@daftari.co'));
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'MAGIC_LINK_SENT');
      verify(() => admin.savePendingEmail('owner@daftari.co')).called(1);
      await sub.cancel();
      await bloc.close();
    });

    test('MagicLinkCompleted completes the sign-in → stage decision', () async {
      when(
        () => admin.tenantAccounts(idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => Right([
          {'username': 'boss'},
        ]),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const MagicLinkCompleted('owner@daftari.co', 'https://link'));
      await bloc.stream.firstWhere((s) => s is CredentialsStage);
      verify(
        () => firebase.signInWithEmailLink(
          email: 'owner@daftari.co',
          link: 'https://link',
        ),
      ).called(1);
      await sub.cancel();
      await bloc.close();
    });
  });

  group('Credentials stage', () {
    test('no stored tenant → FirebaseStage (stage 1 must run first)', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => null);
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
      await bloc.stream.firstWhere((s) => s is FirebaseStage);
      expect(states.last, isA<FirebaseStage>());
      await sub.cancel();
      await bloc.close();
    });

    test(
      'valid credentials → AuthAuthenticated (session token, staff)',
      () async {
        when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
        when(
          () => admin.credentialLogin(
            tenantId: any(named: 'tenantId'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => Right(
            const AdminCredentials(
              token: 'session-jwt',
              sessionId: 'sess-1',
              profile: {'tenant_id': 'uid-123'},
            ),
          ),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        final state = states.last as AuthAuthenticated;
        expect(state.isOwner, isFalse);
        expect(state.token, 'session-jwt');
        await sub.cancel();
        await bloc.close();
      },
    );

    test('BAD_CREDENTIALS → AuthError with the Arabic message', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(
        () => admin.credentialLogin(
          tenantId: any(named: 'tenantId'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Left(AdminAuthFailure('BAD_CREDENTIALS')),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CredentialsSubmitted('admin', 'wrong'));
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'BAD_CREDENTIALS');
      expect(state.messageAr, 'بيانات الدخول غير صحيحة.');
      await sub.cancel();
      await bloc.close();
    });

    test('SESSION_CONFLICT → conflict state with the session id', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(
        () => admin.credentialLogin(
          tenantId: any(named: 'tenantId'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(SessionConflictFailure('sess-9')));
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
      await bloc.stream.firstWhere((s) => s is SessionConflict);
      final state = states.last as SessionConflict;
      expect(state.conflictSessionId, 'sess-9');
      expect(state.username, 'admin');
      await sub.cancel();
      await bloc.close();
    });

    test('ForceRevokeRequested revokes then retries → Authenticated', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(() => admin.storedToken()).thenAnswer((_) async => 'session-jwt');
      when(
        () => admin.credentialLogin(
          tenantId: any(named: 'tenantId'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => Right(
          const AdminCredentials(
            token: 'session-jwt-2',
            sessionId: 'sess-2',
            profile: {'tenant_id': 'uid-123'},
          ),
        ),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const ForceRevokeRequested('admin', 'pw123456'));
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      verify(
        () => admin.revokeSessions(username: 'admin', idToken: 'session-jwt'),
      ).called(1);
      expect(states.last, isA<AuthAuthenticated>());
      await sub.cancel();
      await bloc.close();
    });

    test('LogoutRequested clears the session → FirebaseStage', () async {
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LogoutRequested());
      await bloc.stream.firstWhere((s) => s is FirebaseStage);
      verify(() => admin.clearSession()).called(1);
      verify(() => firebase.signOut()).called(1);
      await sub.cancel();
      await bloc.close();
    });
  });
}
