// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Environment configuration for Daftari POS.
///
/// Three environments:
/// - `development`: Local development with debug features
/// - `staging`: Pre-production testing with production-like config
/// - `production`: Production releases
enum AppEnv { development, staging, production }

/// Environment configuration loaded from dart-defines.
class EnvConfig {
  /// Current environment (set at build time via --dart-define).
  static late final AppEnv env;

  /// Firebase Functions URL (deprecated; use apiBaseUrl).
  static late final String firebaseFunctionsUrl;

  /// Legacy Cloudflare Worker URL (deprecated; use apiBaseUrl).
  static late final String cloudflareWorkerUrl;

  /// API worker base URL (daftari-api Cloudflare Worker).
  static late final String apiBaseUrl;

  /// Realtime worker URL (daftari-realtime, WebSocket endpoint).
  static late final String realtimeWsUrl;

  /// Turso database URL.
  static late final String tursoDbUrl;

  /// Firebase project ID.
  static late final String firebaseProjectId;

  /// Firebase WEB app config (public by design — identifies the project to
  /// Firebase's servers; protection = authorized domains + server checks).
  static late final String firebaseWebApiKey;
  static late final String firebaseWebAuthDomain;
  static late final String firebaseWebMessagingSenderId;
  static late final String firebaseWebAppId;

  /// The admin dashboard's own origin (magic-link continueUrl target).
  /// Overridable via --dart-define=ADMIN_ORIGIN for local flutter run.
  static late final String adminOrigin;

  /// Enable debug logging.
  static late final bool enableLogging;

  /// Enable Crashlytics.
  static late final bool enableCrashlytics;

  /// Shorebird app ID.
  static late final String shorebirdAppId;

  static const _firebaseWebApiKey = 'AIzaSyBGjEpwrZEuLtFTJC27ZXCELrwShoKj8Qk';
  static const _firebaseWebAuthDomain = 'daftari-pos.firebaseapp.com';
  static const _firebaseWebMessagingSenderId = '905067437740';
  static const _firebaseWebAppId = '1:905067437740:web:6ce2c15255db6ea27bc909';

  /// Initialize from environment variables (dart-defines).
  static void initializeFromEnv() {
    const envName = String.fromEnvironment('ENV', defaultValue: 'development');
    final config = _createFromEnvName(envName);
    EnvConfig.env = config.env;
    EnvConfig.firebaseFunctionsUrl = config.firebaseFunctionsUrl;
    EnvConfig.cloudflareWorkerUrl = config.cloudflareWorkerUrl;
    EnvConfig.apiBaseUrl = config.apiBaseUrl;
    EnvConfig.realtimeWsUrl = config.realtimeWsUrl;
    EnvConfig.tursoDbUrl = config.tursoDbUrl;
    EnvConfig.firebaseProjectId = config.firebaseProjectId;
    EnvConfig.enableLogging = config.enableLogging;
    EnvConfig.enableCrashlytics = config.enableCrashlytics;
    EnvConfig.shorebirdAppId = config.shorebirdAppId;
    EnvConfig.firebaseWebApiKey = _firebaseWebApiKey;
    EnvConfig.firebaseWebAuthDomain = _firebaseWebAuthDomain;
    EnvConfig.firebaseWebMessagingSenderId = _firebaseWebMessagingSenderId;
    EnvConfig.firebaseWebAppId = _firebaseWebAppId;
    const overrideOrigin = String.fromEnvironment('ADMIN_ORIGIN');
    EnvConfig.adminOrigin = overrideOrigin.isNotEmpty
        ? overrideOrigin
        : config.adminOrigin;
  }

  static _EnvConfigData _createFromEnvName(String envName) {
    return switch (envName) {
      'development' => _EnvConfigData._(
        env: AppEnv.development,
        firebaseFunctionsUrl:
            'https://us-central1-daftari-dev.cloudfunctions.net',
        cloudflareWorkerUrl: 'https://api-dev.daftariapp.workers.dev',
        apiBaseUrl: 'https://api-dev.daftariapp.workers.dev',
        realtimeWsUrl: 'wss://realtime-dev.daftariapp.workers.dev/ws',
        tursoDbUrl: 'libsql://daftari-dev-xyz.turso.io',
        firebaseProjectId: 'daftari-pos',
        adminOrigin: 'https://admin-dev.daftariapp.workers.dev',
        enableLogging: true,
        enableCrashlytics: false,
        shorebirdAppId: '',
      ),
      'staging' => _EnvConfigData._(
        env: AppEnv.staging,
        firebaseFunctionsUrl:
            'https://us-central1-daftari-staging.cloudfunctions.net',
        cloudflareWorkerUrl: 'https://api-staging.daftariapp.workers.dev',
        apiBaseUrl: 'https://api-staging.daftariapp.workers.dev',
        realtimeWsUrl: 'wss://realtime-staging.daftariapp.workers.dev/ws',
        tursoDbUrl: 'libsql://daftari-staging-xyz.turso.io',
        firebaseProjectId: 'daftari-pos',
        adminOrigin: 'https://admin-staging.daftariapp.workers.dev',
        enableLogging: true,
        enableCrashlytics: true,
        shorebirdAppId: '',
      ),
      'production' => _EnvConfigData._(
        env: AppEnv.production,
        firebaseFunctionsUrl:
            'https://us-central1-daftari-prod.cloudfunctions.net',
        cloudflareWorkerUrl: 'https://api.daftariapp.workers.dev',
        apiBaseUrl: 'https://api.daftariapp.workers.dev',
        realtimeWsUrl: 'wss://realtime.daftariapp.workers.dev/ws',
        tursoDbUrl: 'libsql://daftari-prod-xyz.turso.io',
        firebaseProjectId: 'daftari-pos',
        adminOrigin: 'https://admin.daftariapp.workers.dev',
        enableLogging: false,
        enableCrashlytics: true,
        shorebirdAppId: 'prod-app-id',
      ),
      _ => throw Exception('Unknown env: $envName'),
    };
  }

  const EnvConfig._();
}

class _EnvConfigData {
  final AppEnv env;
  final String firebaseFunctionsUrl;
  final String cloudflareWorkerUrl;
  final String apiBaseUrl;
  final String realtimeWsUrl;
  final String tursoDbUrl;
  final String firebaseProjectId;
  final String adminOrigin;
  final bool enableLogging;
  final bool enableCrashlytics;
  final String shorebirdAppId;

  const _EnvConfigData._({
    required this.env,
    required this.firebaseFunctionsUrl,
    required this.cloudflareWorkerUrl,
    required this.apiBaseUrl,
    required this.realtimeWsUrl,
    required this.tursoDbUrl,
    required this.firebaseProjectId,
    required this.adminOrigin,
    required this.enableLogging,
    required this.enableCrashlytics,
    required this.shorebirdAppId,
  });
}
