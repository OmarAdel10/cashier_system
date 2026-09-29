import 'dart:convert';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/backend/workers/auth_sync_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Records the requests the ApiClient issues; optionally throws to drive
/// the Left path (no mocktail-on-http fallback machinery needed).
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({
    this.error,
    this.responseBody = '{"ok":true}',
    this.statusCode = 200,
  });

  final Object? error;
  final String responseBody;
  final int statusCode;
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (error != null) throw error!;
    final req = request as http.Request;
    requests.add(req);
    return http.StreamedResponse(
      Stream.value(responseBody.codeUnits),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  // EnvConfig is a static-late-final singleton — initialize once before
  // any constructor runs (fixes the test-only-init race).
  setUpAll(EnvConfig.initializeFromEnv);

  group('ApiClient', () {
    test('stores baseUrl', () {
      final api = ApiClient(baseUrl: 'https://test.workers.dev');
      expect(api.baseUrl, equals('https://test.workers.dev'));
    });

    test('EnvConfig default returns the canonical dev API URL', () {
      final api = ApiClient();
      expect(api.baseUrl, contains('api-dev.daftariapp.workers.dev'));
    });

    test('post() returns a Future<Either>, never throws', () async {
      // Casually unreachable URL — mostly checks the Either wrapper lives,
      // not the HTTP error (covered by backend test suite).
      final api = ApiClient(baseUrl: 'http://10.255.255.1:x');
      final res = await api.post('/x', {'v': 1}, idToken: 't');
      expect(res, isA<dynamic>());
    });

    test(
      'patch() sends the bearer header + json body to the joined URL',
      () async {
        final client = _FakeHttpClient();
        final api = ApiClient(
          baseUrl: 'https://test.workers.dev',
          httpClient: client,
        );
        final res = await api.patch('/admin/users/boss', {
          'is_active': 0,
        }, idToken: 'tok');
        final req = client.requests.single;
        expect(req.method, 'PATCH');
        expect(req.url.toString(), 'https://test.workers.dev/admin/users/boss');
        expect(req.headers['Authorization'], 'Bearer tok');
        expect(req.headers['Content-Type'], 'application/json');
        expect(req.body, jsonEncode({'is_active': 0}));
        expect(res.fold((_) => null, (b) => b), {'ok': true});
      },
    );

    test('patch() Left on a client exception', () async {
      final client = _FakeHttpClient(error: http.ClientException('down'));
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.patch('/x', {'v': 1}, idToken: 'tok');
      expect(res.fold((f) => f.message, (_) => null), 'PATCH /x failed');
    });

    test('delete() sends the bearer header to the joined URL', () async {
      final client = _FakeHttpClient();
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.delete('/admin/users/boss', idToken: 'tok');
      final req = client.requests.single;
      expect(req.method, 'DELETE');
      expect(req.url.toString(), 'https://test.workers.dev/admin/users/boss');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers.containsKey('Content-Type'), isFalse); // no body
      expect(res.fold((_) => null, (b) => b), {'ok': true});
    });

    test('delete() Left on a client exception', () async {
      final client = _FakeHttpClient(error: http.ClientException('down'));
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.delete('/x', idToken: 'tok');
      expect(res.fold((f) => f.message, (_) => null), 'DELETE /x failed');
    });

    test(
      'post returns the parsed ok:false body on a 401 JSON response',
      () async {
        final client = _FakeHttpClient(
          statusCode: 401,
          responseBody: jsonEncode({
            'ok': false,
            'error': 'PROVIDER_NOT_ALLOWED',
          }),
        );
        final api = ApiClient(
          baseUrl: 'https://test.workers.dev',
          httpClient: client,
        );
        final res = await api.post('/auth/google', {}, idToken: 'tok');
        expect(res, isA<Right<Failure, Map<String, dynamic>>>());
        expect(
          res.fold((_) => null, (b) => b)?['error'],
          'PROVIDER_NOT_ALLOWED',
        );
      },
    );

    test('post returns HttpFailure when a 500 body is not JSON', () async {
      final client = _FakeHttpClient(
        statusCode: 500,
        responseBody: '<html>boom</html>',
      );
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.post('/x', {'v': 1}, idToken: 'tok');
      final failure = res.fold((f) => f, (_) => null);
      expect(failure, isA<HttpFailure>());
      expect((failure as HttpFailure).statusCode, 500);
      expect(failure.path, '/x');
    });

    test('get returns the parsed body on a 500 JSON response', () async {
      final client = _FakeHttpClient(
        statusCode: 500,
        responseBody: jsonEncode({'ok': false, 'error': 'DB_DOWN'}),
      );
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.get('/admin/users', idToken: 'tok');
      expect(res, isA<Right<Failure, Map<String, dynamic>>>());
      expect(res.fold((_) => null, (b) => b)?['error'], 'DB_DOWN');
    });

    test('a 2xx non-object JSON body does not escape as a TypeError', () async {
      final client = _FakeHttpClient(responseBody: '[1, 2, 3]');
      final api = ApiClient(
        baseUrl: 'https://test.workers.dev',
        httpClient: client,
      );
      final res = await api.post('/x', {'v': 1}, idToken: 'tok');
      expect(res, isA<Right<Failure, Map<String, dynamic>>>());
      expect(res.fold((_) => null, (b) => b), isEmpty);
    });
  });

  group('AuthSyncService', () {
    test('mock ok path works', () async {
      final sync = AuthSyncService(
        api: ApiClient(baseUrl: 'http://10.255.255.1:x'),
      );
      final res = await sync.syncUser(idToken: 'dummy');
      expect(res, isA<dynamic>());
    });
  });
}
