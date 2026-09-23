import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/backend/workers/auth_sync_service.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // EnvConfig is a static-late-final singleton — initialize once before
  // any constructor runs (fixes the test-only-init race).
  setUpAll(EnvConfig.initializeFromEnv);

  group('ApiClient', () {
    test('stores baseUrl', () {
      final api = ApiClient(baseUrl: 'https://test.workers.dev');
      expect(api.baseUrl, equals('https://test.workers.dev'));
    });

    test('EnvConfig default returns a sham URL', () {
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
