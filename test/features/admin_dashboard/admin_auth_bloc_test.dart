// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

String _jwt(Map<String, dynamic> payload) {
  String seg(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.sig';
}

/// A stored session JWT that is unexpired for the next hour.
String _liveJwt() => _jwt({
  'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
  'tid': 'tenant-1',
  'usr': 'boss',
  'role': 'admin',
  'jti': 'sess-1',
});

/// A stored session JWT whose exp already passed.
String _expiredJwt() => _jwt({
  'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 10,
  'tid': 'tenant-1',
  'usr': 'boss',
  'role': 'admin',
  'jti': 'sess-1',
});

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;
  late MockUserCredential credential;
  late MockUser user;

  setUpAll(() {
    // The bloc gates its failure logging on EnvConfig.enableLogging — a
    // static late-final singleton that must be initialized before use.
    EnvConfig.initializeFromEnv();
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
    when(() => admin.saveTenantId(any())).thenAnswer((_) async {});
    // The session-resume path (T11) — default to 'nothing stored' so the
    // existing stage tests keep falling through to the old behaviour.
    when(() => admin.storedToken()).thenAnswer((_) async => null);
    when(() => admin.validToken()).thenAnswer((_) async => null);
    when(
      () => admin.resumeSession(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Left(AdminAuthFailure('SESSION_STALE')));
    when(
      () => admin.logout(idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(null));
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

    test(
      'stored token without tenant → FirebaseStage (stage 1 must establish it)',
      () async {
        // T11 QA: a session JWT can outlive the tenant write (the old flow
        // never persisted the tenant at all) — the gate must still send the
        // user to Stage 1 instead of a credential login without a tenant.
        when(() => admin.storedToken()).thenAnswer((_) async => 'jwt-token');
        when(() => admin.storedTenantId()).thenAnswer((_) async => null);
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const CheckSessionRequested());
        await bloc.stream.firstWhere((s) => s is FirebaseStage);
        expect(states.first, isA<AuthLoading>());
        expect(states.last, isA<FirebaseStage>());
        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'resumes a stored unexpired JWT without emitting CredentialsStage',
      () async {
        // T11: F5/reload must resume the live session, not bounce the admin
        // back to the credential card.
        final token = _liveJwt();
        when(() => admin.storedToken()).thenAnswer((_) async => token);
        when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
        when(
          () => admin.resumeSession(idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right(
            SessionResume(
              token: 'fresh-jwt',
              sessionId: 'sess-2',
              profile: {'username': 'boss'},
            ),
          ),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const CheckSessionRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        final state = states.last as AuthAuthenticated;
        expect(state.token, 'fresh-jwt');
        expect(state.isOwner, isFalse);
        expect(state.profile, {'username': 'boss'});
        verify(() => admin.resumeSession(idToken: token)).called(1);
        expect(states.whereType<CredentialsStage>(), isEmpty);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('OWNER_REAUTH_REQUIRED on resume → AuthError, not a resume', () async {
      when(() => admin.storedToken()).thenAnswer((_) async => _liveJwt());
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(
        () => admin.resumeSession(idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Left(AdminAuthFailure('OWNER_REAUTH_REQUIRED')),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CheckSessionRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'OWNER_REAUTH_REQUIRED');
      expect(state.messageAr, isNotEmpty);
      expect(states.whereType<AuthAuthenticated>(), isEmpty);
      expect(states.whereType<CredentialsStage>(), isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test(
      'SESSION_REVOKED on resume → AuthError for the Firebase card',
      () async {
        when(() => admin.storedToken()).thenAnswer((_) async => _liveJwt());
        when(
          () => admin.resumeSession(idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Left(AdminAuthFailure('SESSION_REVOKED')),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const CheckSessionRequested());
        await bloc.stream.firstWhere((s) => s is AuthError);
        expect((states.last as AuthError).code, 'SESSION_REVOKED');
        await sub.cancel();
        await bloc.close();
      },
    );

    test('an expired stored JWT falls through to the old behaviour', () async {
      // No resume attempt: the token cannot be validated, so the existing
      // stage decision runs (tenant known → CredentialsStage).
      when(() => admin.storedToken()).thenAnswer((_) async => _expiredJwt());
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CheckSessionRequested());
      await bloc.stream.firstWhere((s) => s is CredentialsStage);
      expect(states.last, isA<CredentialsStage>());
      verifyNever(() => admin.resumeSession(idToken: any(named: 'idToken')));
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
      // T11 QA: the Stage-1 login persists the tenant so the daily
      // credential stage can complete (the only old writer was
      // credentialLogin itself — a fresh browser bounced forever).
      verify(() => admin.saveTenantId('tenant-1')).called(1);
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

    test('accounts-check failure → AuthError (never bootstrap)', () async {
      // T11 QA: a failed accounts REQUEST is not an empty list — bootstrapping
      // on it would skip the credentials stage on a transient error.
      when(
        () => admin.tenantAccounts(idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'ACCOUNTS_CHECK_FAILED');
      expect(states.whereType<AuthAuthenticated>(), isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('ACCOUNTS_CHECK_FAILED carries the server error code', () async {
      when(
        () => admin.tenantAccounts(idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Left(AdminAuthFailure('EMAIL_NOT_VERIFIED')),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'EMAIL_NOT_VERIFIED');
      expect(states.whereType<AuthAuthenticated>(), isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('a Firebase failure keeps the FirebaseAuthException code', () async {
      when(() => firebase.signInWithGooglePopup()).thenAnswer(
        (_) async => const Left(
          DatabaseFailure(
            'The popup has been closed by the user.',
            detail: 'auth/popup-closed-by-user',
          ),
        ),
      );
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'auth/popup-closed-by-user');
      // The real code stays visible even without a dedicated Arabic string.
      expect(state.messageAr, contains('(auth/popup-closed-by-user)'));
      await sub.cancel();
      await bloc.close();
    });

    test(
      'a null ID token after a successful sign-in → FIREBASE_FAILED',
      () async {
        when(() => firebase.currentIdToken()).thenAnswer((_) async => null);
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthError);
        final state = states.last as AuthError;
        expect(state.code, 'FIREBASE_FAILED');
        verifyNever(() => admin.refreshOwner(idToken: any(named: 'idToken')));
        verifyNever(() => admin.tenantAccounts(idToken: any(named: 'idToken')));
        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'an empty Firebase tenant id skips saveTenantId (bootstrap proceeds)',
      () async {
        when(() => firebase.tenantId).thenReturn('');
        when(
          () => admin.tenantAccounts(idToken: any(named: 'idToken')),
        ).thenAnswer((_) async => const Right([]));
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        verifyNever(() => admin.saveTenantId(any()));
        final state = states.last as AuthAuthenticated;
        expect(state.profile['tenant_id'], '');
        await sub.cancel();
        await bloc.close();
      },
    );
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

    test(
      'MagicLinkRequested failure → MAGIC_LINK_FAILED (no email saved)',
      () async {
        when(
          () => firebase.sendMagicLink(email: any(named: 'email')),
        ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const MagicLinkRequested('owner@daftari.co'));
        await bloc.stream.firstWhere((s) => s is AuthError);
        final state = states.last as AuthError;
        expect(state.code, 'MAGIC_LINK_FAILED');
        expect(state.messageAr, 'فشل إرسال الرابط. حاول مجددًا.');
        verifyNever(() => admin.savePendingEmail(any()));
        await sub.cancel();
        await bloc.close();
      },
    );

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

    test(
      'SessionConflict keeps only the widget-supplied retry, no password',
      () {
        // The plaintext password must never live in bloc state (T27). The
        // class has no `password` field at all, so this construction would
        // not compile against the old shape.
        var retried = 0;
        final state = SessionConflict(
          username: 'admin',
          conflictSessionId: 'sess-9',
          retry: () => retried++,
        );
        state.retry();
        expect(retried, 1);
      },
    );

    test('a submitted conflict carries the widget retry through', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(
        () => admin.credentialLogin(
          tenantId: any(named: 'tenantId'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(SessionConflictFailure('sess-9')));
      var retried = 0;
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(
        CredentialsSubmitted(
          'admin',
          'pw123456',
          onConflictRetry: () {
            retried++;
          },
        ),
      );
      await bloc.stream.firstWhere((s) => s is SessionConflict);
      (states.last as SessionConflict).retry();
      expect(retried, 1);
      await sub.cancel();
      await bloc.close();
    });

    test('a non-admin Failure (DatabaseFailure) → AuthError UNKNOWN', () async {
      when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
      when(
        () => admin.credentialLogin(
          tenantId: any(named: 'tenantId'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(DatabaseFailure('network boom')));
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
      await bloc.stream.firstWhere((s) => s is AuthError);
      final state = states.last as AuthError;
      expect(state.code, 'UNKNOWN');
      expect(state.messageAr, 'فشل تسجيل الدخول. حاول مجددًا.');
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

    test(
      'ForceRevoke with no stored JWT → falls back to the Stage-1 Firebase token',
      () async {
        // T11 QA: a fresh browser has no stored session JWT — the revoke must
        // use the Stage-1 Firebase token kept in memory, or the conflict
        // dialog loops (spec §6.5).
        when(() => admin.storedToken()).thenAnswer((_) async => null);
        when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
        when(
          () => admin.tenantAccounts(idToken: any(named: 'idToken')),
        ).thenAnswer((_) async => const Right([]));
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
              sessionId: 'sess-3',
              profile: {'tenant_id': 'uid-123'},
            ),
          ),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        // Stage 1 (bootstrap) keeps the firebase token in memory.
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        bloc.add(const ForceRevokeRequested('admin', 'pw123456'));
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        verify(
          () => admin.revokeSessions(
            username: 'admin',
            idToken: 'firebase-id-token',
          ),
        ).called(1);
        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'ForceRevoke with both tokens rejected → REVOKE_FAILED error',
      () async {
        when(() => admin.storedToken()).thenAnswer((_) async => 'expired-jwt');
        when(
          () => admin.tenantAccounts(idToken: any(named: 'idToken')),
        ).thenAnswer((_) async => const Right([]));
        when(
          () => admin.revokeSessions(
            username: any(named: 'username'),
            idToken: any(named: 'idToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(AdminAuthFailure('Invalid session token')),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        bloc.add(const ForceRevokeRequested('admin', 'pw123456'));
        await bloc.stream.firstWhere((s) => s is AuthError);
        final state = states.last as AuthError;
        expect(state.code, 'REVOKE_FAILED');
        // The re-login must NOT have been attempted after a failed revoke.
        verifyNever(
          () => admin.credentialLogin(
            tenantId: any(named: 'tenantId'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        );
        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'ForceRevoke with no stored JWT and the Firebase-token revoke rejected → REVOKE_FAILED',
      () async {
        // T11 QA: the stored-token-missing path where the Stage-1 Firebase
        // fallback ALSO fails — the conflict dialog must surface
        // REVOKE_FAILED instead of looping.
        when(() => admin.storedToken()).thenAnswer((_) async => null);
        when(
          () => admin.tenantAccounts(idToken: any(named: 'idToken')),
        ).thenAnswer((_) async => const Right([]));
        when(
          () => admin.revokeSessions(
            username: any(named: 'username'),
            idToken: any(named: 'idToken'),
          ),
        ).thenAnswer(
          (_) async => const Left(AdminAuthFailure('Invalid session token')),
        );
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        // Stage 1 (bootstrap) keeps the firebase token in memory.
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
        bloc.add(const ForceRevokeRequested('admin', 'pw123456'));
        await bloc.stream.firstWhere((s) => s is AuthError);
        final state = states.last as AuthError;
        expect(state.code, 'REVOKE_FAILED');
        verify(
          () => admin.revokeSessions(
            username: 'admin',
            idToken: 'firebase-id-token',
          ),
        ).called(1);
        verifyNever(
          () => admin.credentialLogin(
            tenantId: any(named: 'tenantId'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        );
        await sub.cancel();
        await bloc.close();
      },
    );

    test(
      'ForceRevoke with BOTH tokens missing → REVOKE_FAILED, no revoke call',
      () async {
        // A bloc that never completed a Stage-1 sign-in has neither the
        // stored session JWT nor the in-memory Firebase token — the revoke
        // is skipped entirely and REVOKE_FAILED is emitted.
        when(() => admin.storedToken()).thenAnswer((_) async => null);
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const ForceRevokeRequested('admin', 'pw123456'));
        await bloc.stream.firstWhere((s) => s is AuthError);
        final state = states.last as AuthError;
        expect(state.code, 'REVOKE_FAILED');
        verifyNever(
          () => admin.revokeSessions(
            username: any(named: 'username'),
            idToken: any(named: 'idToken'),
          ),
        );
        verifyNever(
          () => admin.credentialLogin(
            tenantId: any(named: 'tenantId'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        );
        await sub.cancel();
        await bloc.close();
      },
    );

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

    test(
      'LogoutRequested posts /auth/logout before clearing the session',
      () async {
        // T10: the server must end the session row too — otherwise a reload
        // resumes the session the user just logged out of.
        when(() => admin.storedToken()).thenAnswer((_) async => 'session-jwt');
        final order = <String>[];
        when(() => admin.logout(idToken: any(named: 'idToken'))).thenAnswer((
          _,
        ) async {
          order.add('logout');
          return const Right(null);
        });
        when(() => admin.clearSession()).thenAnswer((_) async {
          order.add('clear');
        });
        final bloc = makeBloc();
        final states = <AdminAuthState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const LogoutRequested());
        await bloc.stream.firstWhere((s) => s is FirebaseStage);
        expect(order, ['logout', 'clear']);
        verify(() => admin.logout(idToken: 'session-jwt')).called(1);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('LogoutRequested with no stored JWT skips the logout call', () async {
      final bloc = makeBloc();
      final states = <AdminAuthState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const LogoutRequested());
      await bloc.stream.firstWhere((s) => s is FirebaseStage);
      verifyNever(() => admin.logout(idToken: any(named: 'idToken')));
      verify(() => admin.clearSession()).called(1);
      await sub.cancel();
      await bloc.close();
    });

    test(
      'remaining AdminAuthFailure codes map to their Arabic messages',
      () async {
        // The _arabicFor switch arms the earlier tests don't reach — each is
        // a distinct user-facing message (the default arm covers unknown
        // codes).
        const cases = <String, String>{
          'OWNER_REAUTH_REQUIRED':
              'يلزم تسجيل دخول المالك عبر جوجل أو الرابط للمتابعة.',
          'DASHBOARD_ADMIN_ONLY': 'حسابات الكاشير لا تدخل لوحة التحكم.',
          'LOGIN_LOCKED':
              'تم قفل الحساب مؤقتًا بسبب محاولات فاشلة متكررة. حاول بعد قليل.',
          'MAGIC_LINK_SENT':
              'تحقق من بريدك الإلكتروني واضغط الرابط لتسجيل الدخول.',
          'WEIRD_CODE': 'فشل تسجيل الدخول. حاول مجددًا. (WEIRD_CODE)',
        };
        when(() => admin.storedTenantId()).thenAnswer((_) async => 'uid-123');
        for (final entry in cases.entries) {
          when(
            () => admin.credentialLogin(
              tenantId: any(named: 'tenantId'),
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => Left(AdminAuthFailure(entry.key)));
          final bloc = makeBloc();
          final states = <AdminAuthState>[];
          final sub = bloc.stream.listen(states.add);
          bloc.add(const CredentialsSubmitted('admin', 'pw123456'));
          await bloc.stream.firstWhere((s) => s is AuthError);
          final state = states.last as AuthError;
          expect(state.code, entry.key);
          expect(state.messageAr, entry.value);
          await sub.cancel();
          await bloc.close();
        }
      },
    );
  });
}
