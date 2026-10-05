// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

String _seg(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _jwt(Map<String, dynamic> payload) =>
    '${_seg({'alg': 'HS256', 'typ': 'JWT'})}.${_seg(payload)}.sig';

/// An HS256-shaped token whose payload segment is the raw [bytes] — used to
/// exercise the malformed-payload branch of [decodeSession].
String _rawPayloadJwt(List<int> bytes) =>
    '${_seg({'alg': 'HS256'})}.${base64Url.encode(bytes).replaceAll('=', '')}.sig';

Map<String, dynamic> _claims({
  int? exp,
  String? tid,
  String? usr,
  String? role,
  String? jti,
}) => {
  if (exp != null) 'exp': exp,
  if (tid != null) 'tid': tid,
  if (usr != null) 'usr': usr,
  if (role != null) 'role': role,
  if (jti != null) 'jti': jti,
};

Map<String, dynamic> _fullClaims({
  int exp = 2000000000,
  String tid = 'tenant-1',
  String usr = 'boss',
  String role = 'admin',
  String jti = 'sess-1',
}) => _claims(exp: exp, tid: tid, usr: usr, role: role, jti: jti);

void main() {
  late MockApiClient api;
  late MockFlutterSecureStorage storage;

  setUpAll(() {
    // The POST/GET body map is matched with any() — mocktail needs a
    // registered fallback for the Map type.
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    api = MockApiClient();
    storage = MockFlutterSecureStorage();
    when(
      () => api.post(any(), any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(
      () => api.get(any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  AdminAuthService makeService() =>
      AdminAuthService(apiClient: api, storage: storage);

  group('credentialLogin', () {
    test('a failed request → DatabaseFailure', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Left(DatabaseFailure('POST failed')));
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'pw123456',
      );
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect(failure, isA<DatabaseFailure>());
      expect(failure.message, 'Login request failed');
    });

    test(
      'SESSION_CONFLICT → SessionConflictFailure with the session id',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right({
            'ok': false,
            'error': 'SESSION_CONFLICT',
            'conflict_session_id': 'sess-9',
          }),
        );
        final result = await makeService().credentialLogin(
          tenantId: 'uid-123',
          username: 'admin',
          password: 'pw123456',
        );
        final failure = result.fold((f) => f, (_) => fail('Expected Left'));
        expect(failure, isA<SessionConflictFailure>());
        expect((failure as SessionConflictFailure).conflictSessionId, 'sess-9');
      },
    );

    test(
      'SESSION_CONFLICT without a session id → empty conflictSessionId',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right({'ok': false, 'error': 'SESSION_CONFLICT'}),
        );
        final result = await makeService().credentialLogin(
          tenantId: 'uid-123',
          username: 'admin',
          password: 'pw123456',
        );
        final failure = result.fold((f) => f, (_) => fail('Expected Left'));
        expect((failure as SessionConflictFailure).conflictSessionId, '');
      },
    );

    test('ok:false with an error code → AdminAuthFailure', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right({'ok': false, 'error': 'BAD_CREDENTIALS'}),
      );
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'wrong',
      );
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect(failure, isA<AdminAuthFailure>());
      expect((failure as AdminAuthFailure).code, 'BAD_CREDENTIALS');
      // The server error is carried structurally, never re-parsed from a
      // message string.
      expect(failure.detail, 'BAD_CREDENTIALS');
    });

    test('ok:false without an error code → AdminAuthFailure UNKNOWN', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right({'ok': false}));
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'pw123456',
      );
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect((failure as AdminAuthFailure).code, 'UNKNOWN');
    });

    test(
      'success persists the token + tenant and returns credentials',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'token': 'jwt-token',
              'session_id': 'sess-1',
              'profile': {'username': 'boss'},
            },
          }),
        );
        final result = await makeService().credentialLogin(
          tenantId: 'uid-123',
          username: 'admin',
          password: 'pw123456',
        );
        final creds = result.fold((_) => fail('Expected Right'), (c) => c);
        expect(creds.token, 'jwt-token');
        expect(creds.sessionId, 'sess-1');
        expect(creds.profile, {'username': 'boss'});
        verify(
          () => storage.write(key: 'admin_session_jwt', value: 'jwt-token'),
        ).called(1);
        verify(
          () => storage.write(key: 'admin_tenant_id', value: 'uid-123'),
        ).called(1);
        // The login request carries the tenant + username + password.
        final body =
            verify(
                  () => api.post('/auth/login', captureAny(), idToken: ''),
                ).captured.single
                as Map<String, dynamic>;
        expect(body, {
          'tenant_id': 'uid-123',
          'username': 'admin',
          'password': 'pw123456',
        });
      },
    );

    test('success without a profile → an empty profile map', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right({
          'ok': true,
          'data': {'token': 'jwt-2', 'session_id': 'sess-2'},
        }),
      );
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'pw123456',
      );
      final creds = result.fold((_) => fail('Expected Right'), (c) => c);
      expect(creds.profile, isEmpty);
    });

    test('ok:true with a missing data object → DatabaseFailure', () async {
      // A malformed success body must be a Left, not a TypeError escaping
      // the bloc (the old code force-unwrapped body['data']!).
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right({'ok': true}));
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'pw123456',
      );
      expect(
        result.fold((f) => f, (_) => fail('Expected Left')),
        isA<DatabaseFailure>(),
      );
    });

    test('ok:true with a missing token → DatabaseFailure', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right({
          'ok': true,
          'data': {'session_id': 'sess-1'},
        }),
      );
      final result = await makeService().credentialLogin(
        tenantId: 'uid-123',
        username: 'admin',
        password: 'pw123456',
      );
      expect(
        result.fold((f) => f, (_) => fail('Expected Left')),
        isA<DatabaseFailure>(),
      );
    });
  });

  group('refreshOwner', () {
    test(
      'passes the api result through (Left on failure, Right on success)',
      () async {
        var calls = 0;
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer((_) async {
          calls++;
          return calls == 1
              ? const Left(DatabaseFailure('boom'))
              : const Right({});
        });
        final service = makeService();
        final failed = await service.refreshOwner(idToken: 'tok');
        expect(failed, isA<Left<Failure, void>>());
        final passed = await service.refreshOwner(idToken: 'tok');
        expect(passed, isA<Right<Failure, void>>());
      },
    );
  });

  group('tenantAccounts', () {
    test('ok:false → AdminAuthFailure', () async {
      when(() => api.get(any(), idToken: any(named: 'idToken'))).thenAnswer(
        (_) async => const Right({'ok': false, 'error': 'INVALID_TOKEN'}),
      );
      final result = await makeService().tenantAccounts(idToken: 'tok');
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect(failure, isA<AdminAuthFailure>());
      expect((failure as AdminAuthFailure).code, 'INVALID_TOKEN');
      expect(failure.detail, 'INVALID_TOKEN');
    });

    test('missing data/users → an empty list (not a failure)', () async {
      when(
        () => api.get(any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right({'ok': true}));
      final result = await makeService().tenantAccounts(idToken: 'tok');
      expect(result.fold((_) => fail('Expected Right'), (u) => u), isEmpty);
    });

    test('ok:true → the tenant users', () async {
      when(() => api.get(any(), idToken: any(named: 'idToken'))).thenAnswer(
        (_) async => const Right({
          'ok': true,
          'data': {
            'users': [
              {'username': 'boss'},
            ],
          },
        }),
      );
      final result = await makeService().tenantAccounts(idToken: 'tok');
      final users = result.fold((_) => fail('Expected Right'), (u) => u);
      expect(users, hasLength(1));
      expect(users.single['username'], 'boss');
    });
  });

  group('revokeSessions', () {
    test('ok:false → Left (the conflict dialog must not loop)', () async {
      // T11 QA: the api worker signals 401/403 in the body — a rejected
      // revoke must be a Left, not a Right, or the force-revoke loops.
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async =>
            const Right({'ok': false, 'error': 'Invalid session token'}),
      );
      final result = await makeService().revokeSessions(
        username: 'admin',
        idToken: 'tok',
      );
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect(failure, isA<AdminAuthFailure>());
      expect((failure as AdminAuthFailure).code, 'Invalid session token');
    });

    test('ok:true → Right', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right({'ok': true}));
      final result = await makeService().revokeSessions(
        username: 'admin',
        idToken: 'tok',
      );
      expect(result, isA<Right<Failure, void>>());
    });
  });

  group('storage helpers', () {
    test('read, write, and clear the persisted keys', () async {
      when(
        () => storage.read(key: 'admin_session_jwt'),
      ).thenAnswer((_) async => 'jwt-token');
      when(
        () => storage.read(key: 'admin_tenant_id'),
      ).thenAnswer((_) async => 'uid-123');
      when(
        () => storage.read(key: 'admin_pending_email'),
      ).thenAnswer((_) async => 'owner@daftari.co');
      final service = makeService();
      expect(await service.storedToken(), 'jwt-token');
      expect(await service.storedTenantId(), 'uid-123');
      expect(await service.pendingMagicEmail(), 'owner@daftari.co');
      await service.saveTenantId('uid-9');
      verify(
        () => storage.write(key: 'admin_tenant_id', value: 'uid-9'),
      ).called(1);
      await service.savePendingEmail('new@daftari.co');
      verify(
        () =>
            storage.write(key: 'admin_pending_email', value: 'new@daftari.co'),
      ).called(1);
      await service.clearSession();
      verify(() => storage.delete(key: 'admin_session_jwt')).called(1);
      verify(() => storage.delete(key: 'admin_tenant_id')).called(1);
      verifyNever(() => storage.delete(key: 'admin_pending_email'));
    });
  });

  group('decodeSession', () {
    test('decodes exp/tid/usr/role/jti from the JWT payload', () {
      final claims = decodeSession(_jwt(_fullClaims()));
      expect(claims, isNotNull);
      expect(claims!.exp, 2000000000);
      expect(claims.tenantId, 'tenant-1');
      expect(claims.username, 'boss');
      expect(claims.role, 'admin');
      expect(claims.jti, 'sess-1');
    });

    test('returns null for a token without three segments', () {
      expect(decodeSession('not-a-jwt'), isNull);
      expect(decodeSession('a.b'), isNull);
      expect(decodeSession(''), isNull);
    });

    test('returns null when the payload is not valid base64url', () {
      expect(decodeSession('a.%%%%.c'), isNull);
    });

    test('returns null when the payload is not JSON', () {
      expect(decodeSession(_rawPayloadJwt(utf8.encode('not json'))), isNull);
    });

    test('returns null when the payload is JSON but not an object', () {
      expect(decodeSession(_rawPayloadJwt(utf8.encode('[1,2,3]'))), isNull);
    });

    test('returns null when exp is missing or not a number', () {
      expect(
        decodeSession(_jwt(_claims(tid: 't', usr: 'u', role: 'r', jti: 'j'))),
        isNull,
      );
      expect(decodeSession(_jwt({..._fullClaims(), 'exp': 'soon'})), isNull);
    });

    test('returns null when a string claim is missing or empty', () {
      expect(decodeSession(_jwt(_claims(exp: 2000000000))), isNull);
      expect(decodeSession(_jwt({..._fullClaims(), 'jti': ''})), isNull);
    });
  });

  group('validToken', () {
    test('returns the stored JWT when it is unexpired', () async {
      final future = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _jwt(_fullClaims(exp: future));
      when(
        () => storage.read(key: 'admin_session_jwt'),
      ).thenAnswer((_) async => token);
      expect(await makeService().validToken(), token);
    });

    test('returns null when the stored JWT is expired', () async {
      final past = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 10;
      when(
        () => storage.read(key: 'admin_session_jwt'),
      ).thenAnswer((_) async => _jwt(_fullClaims(exp: past)));
      expect(await makeService().validToken(), isNull);
    });

    test('returns null inside the 60s refresh margin', () async {
      final soon = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 30;
      when(
        () => storage.read(key: 'admin_session_jwt'),
      ).thenAnswer((_) async => _jwt(_fullClaims(exp: soon)));
      expect(await makeService().validToken(), isNull);
    });

    test('returns null when the stored JWT is malformed', () async {
      when(
        () => storage.read(key: 'admin_session_jwt'),
      ).thenAnswer((_) async => 'not-a-jwt');
      expect(await makeService().validToken(), isNull);
    });

    test('returns null when nothing is stored', () async {
      expect(await makeService().validToken(), isNull);
    });
  });

  group('resumeSession', () {
    test(
      'success persists the fresh token and returns the resume payload',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'token': 'fresh-jwt',
              'session_id': 'sess-7',
              'profile': {'username': 'boss'},
            },
          }),
        );
        final result = await makeService().resumeSession(idToken: 'old-jwt');
        final resume = result.fold((_) => fail('Expected Right'), (r) => r);
        expect(resume.token, 'fresh-jwt');
        expect(resume.sessionId, 'sess-7');
        expect(resume.profile, {'username': 'boss'});
        verify(
          () => storage.write(key: 'admin_session_jwt', value: 'fresh-jwt'),
        ).called(1);
        final body = verify(
          () => api.post(
            '/auth/session/resume',
            captureAny(),
            idToken: 'old-jwt',
          ),
        ).captured.single;
        expect(body, <String, dynamic>{});
      },
    );

    test(
      'OWNER_REAUTH_REQUIRED → AdminAuthFailure carrying the code',
      () async {
        when(
          () => api.post(any(), any(), idToken: any(named: 'idToken')),
        ).thenAnswer(
          (_) async =>
              const Right({'ok': false, 'error': 'OWNER_REAUTH_REQUIRED'}),
        );
        final result = await makeService().resumeSession(idToken: 'old-jwt');
        final failure = result.fold((f) => f, (_) => fail('Expected Left'));
        expect(failure, isA<AdminAuthFailure>());
        expect((failure as AdminAuthFailure).code, 'OWNER_REAUTH_REQUIRED');
      },
    );

    test('a transport failure → Left', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));
      final result = await makeService().resumeSession(idToken: 'old-jwt');
      expect(result, isA<Left<Failure, SessionResume>>());
    });

    test('ok:true without a token → DatabaseFailure (never a crash)', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right({
          'ok': true,
          'data': {'session_id': 'sess-7'},
        }),
      );
      final result = await makeService().resumeSession(idToken: 'old-jwt');
      expect(
        result.fold((f) => f, (_) => fail('Expected Left')),
        isA<DatabaseFailure>(),
      );
    });
  });

  group('logout', () {
    test('POST /auth/logout with the session bearer → Right', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer((_) async => const Right({'ok': true}));
      final result = await makeService().logout(idToken: 'session-jwt');
      expect(result, isA<Right<Failure, void>>());
      verify(
        () => api.post(
          '/auth/logout',
          <String, dynamic>{},
          idToken: 'session-jwt',
        ),
      ).called(1);
    });

    test('ok:false → AdminAuthFailure', () async {
      when(
        () => api.post(any(), any(), idToken: any(named: 'idToken')),
      ).thenAnswer(
        (_) async => const Right({'ok': false, 'error': 'SESSION_REVOKED'}),
      );
      final result = await makeService().logout(idToken: 'session-jwt');
      final failure = result.fold((f) => f, (_) => fail('Expected Left'));
      expect((failure as AdminAuthFailure).code, 'SESSION_REVOKED');
    });
  });
}
