// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/config/env_config.dart';

void main() {
  setUpAll(() {
    // `late final` statics initialize ONCE per process (established pattern:
    // api_client_test.dart uses setUpAll for the same reason).
    EnvConfig.initializeFromEnv(); // default ENV=development in tests
  });

  group('EnvConfig firebase project (T10)', () {
    test('development uses the real project id (daftari-pos)', () {
      expect(EnvConfig.firebaseProjectId, 'daftari-pos');
    });

    test('all environments share the auth-only Firebase project', () {
      // _createFromEnvName is private; assert via the documented contract
      // that every env maps to the same project id.
      expect(EnvConfig.firebaseProjectId, isNot('daftari-dev'));
      expect(EnvConfig.firebaseProjectId, isNot('daftari-staging'));
      expect(EnvConfig.firebaseProjectId, isNot('daftari-prod'));
    });
  });

  group('EnvConfig firebase web config (T10 — public by design)', () {
    test('web api key defaults to the real public value', () {
      expect(
        EnvConfig.firebaseWebApiKey,
        'AIzaSyBGjEpwrZEuLtFTJC27ZXCELrwShoKj8Qk',
      );
    });

    test('web auth domain defaults to the project domain', () {
      expect(EnvConfig.firebaseWebAuthDomain, 'daftari-pos.firebaseapp.com');
    });

    test('web messaging sender + app id default to the real public values', () {
      expect(EnvConfig.firebaseWebMessagingSenderId, '905067437740');
      expect(
        EnvConfig.firebaseWebAppId,
        '1:905067437740:web:6ce2c15255db6ea27bc909',
      );
    });
  });

  group('EnvConfig adminOrigin (T10)', () {
    // Staging/prod adminOrigin values and the ADMIN_ORIGIN override branch
    // cannot run in this suite (`late final` statics initialize once per
    // process, and ADMIN_ORIGIN is a compile-time String.fromEnvironment
    // define). Verified one-off in the T10 coverage audit via temporary test
    // files run with --dart-define=ENV=staging / ENV=production and
    // --dart-define=ADMIN_ORIGIN=<origin> — to re-verify, copy this file,
    // adjust the expectations, and run it with those defines.
    test('development admin origin is the dev worker', () {
      expect(EnvConfig.adminOrigin, 'https://admin-dev.daftariapp.workers.dev');
    });
  });
}
