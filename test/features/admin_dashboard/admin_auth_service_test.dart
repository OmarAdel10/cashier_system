// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

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
}
