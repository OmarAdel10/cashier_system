import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'flavor_config.dart';

/// Environment configuration loaded from .env files and dart-defines.
///
/// This class provides typed access to environment variables and build-time
/// configuration values. Values are resolved in priority order:
/// 1. dart-define (--dart-define=KEY=VALUE) - highest priority
/// 2. Platform.environment (system env vars)
/// 3. .env file values (loaded at runtime)
/// 4. Default values - lowest priority
class EnvConfig {
  // Private constructor to prevent instantiation
  EnvConfig._();

  /// Initialize environment configuration.
  /// Call this once at app startup.
  static void initialize() {
    // Values are lazily loaded via getters
  }

  /// Get a string value from environment.
  static String _getString(String key, {String? defaultValue}) {
    // Check dart-defines first (compile-time constants)
    // Note: String.fromEnvironment requires const key, so we check common keys
    final dartDefineValue = _getDartDefine(key);
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue;
    }
    // Then platform environment
    final platformValue = Platform.environment[key];
    if (platformValue != null && platformValue.isNotEmpty) {
      return platformValue;
    }
    // Return default
    return defaultValue ?? '';
  }

  /// Get a boolean value from environment.
  static bool _getBool(String key, {bool defaultValue = false}) {
    final dartDefineValue = _getDartDefine(key);
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue.toLowerCase() == 'true' ||
          dartDefineValue == '1' ||
          dartDefineValue.toLowerCase() == 'yes';
    }
    final platformValue = Platform.environment[key];
    if (platformValue != null) {
      return platformValue.toLowerCase() == 'true' ||
          platformValue == '1' ||
          platformValue.toLowerCase() == 'yes';
    }
    return defaultValue;
  }

  /// Get an integer value from environment.
  static int _getInt(String key, {int defaultValue = 0}) {
    final dartDefineValue = _getDartDefine(key);
    if (dartDefineValue.isNotEmpty) {
      return int.tryParse(dartDefineValue) ?? defaultValue;
    }
    final platformValue = Platform.environment[key];
    if (platformValue != null) {
      return int.tryParse(platformValue) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Get value from dart-define (compile-time constants).
  /// Since String.fromEnvironment requires const keys, we check known keys.
  static String _getDartDefine(String key) {
    // This is a workaround - in practice, dart-defines are accessed via
    // const String.fromEnvironment('KEY') at compile time.
    // For dynamic keys, we can only check platform environment.
    // Known dart-define keys are handled inline where needed.
    return '';
  }

  // ==================== API Configuration ====================

  /// Base URL for API calls.
  static String get apiBaseUrl =>
      _getString('API_BASE_URL', defaultValue: FlavorConfig.apiBaseUrl);

  /// API timeout in milliseconds.
  static int get apiTimeoutMs => _getInt('API_TIMEOUT_MS', defaultValue: 30000);

  /// API retry attempts.
  static int get apiRetryAttempts =>
      _getInt('API_RETRY_ATTEMPTS', defaultValue: 3);

  // ==================== Firebase Configuration ====================

  /// Firebase project ID.
  static String get firebaseProjectId => _getString(
    'FIREBASE_PROJECT_ID',
    defaultValue: FlavorConfig.firebaseProjectId,
  );

  /// Firebase API key.
  static String get firebaseApiKey =>
      _getString('FIREBASE_API_KEY', defaultValue: '');

  /// Firebase app ID.
  static String get firebaseAppId =>
      _getString('FIREBASE_APP_ID', defaultValue: '');

  /// Firebase messaging sender ID.
  static String get firebaseMessagingSenderId =>
      _getString('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');

  /// Firebase options for initializing Firebase app.
  /// Returns null if required config is missing (falls back to auto-detection).
  static FirebaseOptions? get firebaseOptions {
    final projectId = firebaseProjectId;
    final apiKey = firebaseApiKey;
    final appId = firebaseAppId;
    final messagingSenderId = firebaseMessagingSenderId;

    if (projectId.isEmpty ||
        apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      projectId: projectId,
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
    );
  }

  // ==================== Database Configuration ====================

  /// Turso database URL.
  static String get tursoDatabaseUrl => _getString(
    'TURSO_DATABASE_URL',
    defaultValue: FlavorConfig.tursoDatabaseUrl,
  );

  /// Turso auth token.
  static String get tursoAuthToken =>
      _getString('TURSO_AUTH_TOKEN', defaultValue: '');

  // ==================== Analytics Configuration ====================

  /// PostHog API key.
  static String get posthogApiKey =>
      _getString('POSTHOG_API_KEY', defaultValue: FlavorConfig.posthogApiKey);

  /// PostHog host.
  static String get posthogHost =>
      _getString('POSTHOG_HOST', defaultValue: FlavorConfig.posthogHost);

  /// Enable analytics (can be overridden by user preference).
  static bool get enableAnalytics => !_getBool(
    'ANALYTICS_DISABLED',
    defaultValue: FlavorConfig.analyticsOptOutDefault,
  );

  // ==================== Feature Flags ====================

  /// Enable offline-first sync.
  static bool get enableOfflineSync => _getBool(
    'ENABLE_OFFLINE_SYNC',
    defaultValue: FlavorConfig.enableOfflineSync,
  );

  /// Enable cloud backup.
  static bool get enableCloudBackup => _getBool(
    'ENABLE_CLOUD_BACKUP',
    defaultValue: FlavorConfig.enableCloudBackup,
  );

  /// Enable multi-store support.
  static bool get enableMultiStore => _getBool(
    'ENABLE_MULTI_STORE',
    defaultValue: FlavorConfig.enableMultiStore,
  );

  /// Enable advanced reporting.
  static bool get enableAdvancedReporting => _getBool(
    'ENABLE_ADVANCED_REPORTING',
    defaultValue: FlavorConfig.enableAdvancedReporting,
  );

  /// Enable PlayStation mode.
  static bool get enablePlaystationMode => _getBool(
    'ENABLE_PLAYSTATION_MODE',
    defaultValue: FlavorConfig.enablePlaystationMode,
  );

  /// Enable Cafe/Restaurant mode.
  static bool get enableCafeMode =>
      _getBool('ENABLE_CAFE_MODE', defaultValue: FlavorConfig.enableCafeMode);

  // ==================== Debug & Monitoring ====================

  /// Enable debug logging.
  static bool get enableDebugLogging => _getBool(
    'ENABLE_DEBUG_LOGGING',
    defaultValue: FlavorConfig.enableDebugLogging,
  );

  /// Enable performance monitoring.
  static bool get enablePerformanceMonitoring => _getBool(
    'ENABLE_PERFORMANCE_MONITORING',
    defaultValue: FlavorConfig.enablePerformanceMonitoring,
  );

  /// Enable crash reporting.
  static bool get enableCrashReporting => _getBool(
    'ENABLE_CRASH_REPORTING',
    defaultValue: FlavorConfig.enableCrashReporting,
  );

  // ==================== License Configuration ====================

  /// License check interval in hours.
  static int get licenseCheckIntervalHours => _getInt(
    'LICENSE_CHECK_INTERVAL_HOURS',
    defaultValue: FlavorConfig.licenseCheckIntervalHours,
  );

  /// License server URL (for online validation).
  static String get licenseServerUrl =>
      _getString('LICENSE_SERVER_URL', defaultValue: '');

  // ==================== Print Server Configuration ====================

  /// Print server port.
  static int get printServerPort =>
      _getInt('PRINT_SERVER_PORT', defaultValue: FlavorConfig.printServerPort);

  /// Print server host.
  static String get printServerHost =>
      _getString('PRINT_SERVER_HOST', defaultValue: '127.0.0.1');

  /// Print server base URL.
  static String get printServerBaseUrl =>
      'http://$printServerHost:$printServerPort';

  // ==================== App Configuration ====================

  /// App version (from pubspec.yaml at build time).
  static String get appVersion =>
      _getString('APP_VERSION', defaultValue: '1.0.0');

  /// Build number.
  static int get buildNumber => _getInt('BUILD_NUMBER', defaultValue: 1);

  /// Build timestamp (ISO 8601).
  static String get buildTimestamp =>
      _getString('BUILD_TIMESTAMP', defaultValue: '');

  /// Git commit SHA.
  static String get gitCommitSha =>
      _getString('GIT_COMMIT_SHA', defaultValue: '');

  /// Git branch name.
  static String get gitBranch => _getString('GIT_BRANCH', defaultValue: '');

  // ==================== Platform Specific ====================

  /// Windows app installer certificate thumbprint.
  static String get windowsCertificateThumbprint =>
      _getString('WINDOWS_CERTIFICATE_THUMBPRINT', defaultValue: '');

  /// Microsoft Store package identity name.
  static String get msStorePackageIdentityName =>
      _getString('MS_STORE_PACKAGE_IDENTITY_NAME', defaultValue: '');

  /// Google Play service account key (base64 encoded).
  static String get playServiceAccountKey =>
      _getString('PLAY_SERVICE_ACCOUNT_KEY', defaultValue: '');

  /// F-Droid repo URL.
  static String get fdroidRepoUrl =>
      _getString('FDROID_REPO_URL', defaultValue: '');

  // ==================== Security ====================

  /// Encryption key for secure storage (base64 encoded).
  static String get encryptionKey =>
      _getString('ENCRYPTION_KEY', defaultValue: '');

  /// JWT secret for API authentication.
  static String get jwtSecret => _getString('JWT_SECRET', defaultValue: '');

  /// Allowed origins for CORS.
  static List<String> get corsAllowedOrigins {
    final value = _getString('CORS_ALLOWED_ORIGINS', defaultValue: '');
    if (value.isEmpty) return [];
    return value.split(',').map((e) => e.trim()).toList();
  }

  // ==================== Validation ====================

  /// Validate required configuration for production.
  static List<String> validateProductionConfig() {
    final errors = <String>[];

    if (FlavorConfig.isProductionLike) {
      if (firebaseProjectId.isEmpty) {
        errors.add('FIREBASE_PROJECT_ID is required for production');
      }
      if (tursoDatabaseUrl.isEmpty) {
        errors.add('TURSO_DATABASE_URL is required for production');
      }
      if (posthogApiKey.isEmpty) {
        errors.add('POSTHOG_API_KEY is required for production');
      }
      if (encryptionKey.isEmpty) {
        errors.add('ENCRYPTION_KEY is required for production');
      }
      if (jwtSecret.isEmpty) {
        errors.add('JWT_SECRET is required for production');
      }
    }

    return errors;
  }

  /// Print current configuration (for debugging).
  static void printConfig() {
    if (!enableDebugLogging) return;

    print('=== EnvConfig ===');
    print('Flavor: ${FlavorConfig.flavor.name}');
    print('API Base URL: $apiBaseUrl');
    print('Firebase Project: $firebaseProjectId');
    print(
      'Turso DB: ${tursoDatabaseUrl.isNotEmpty ? "configured" : "not configured"}',
    );
    print(
      'PostHog: ${posthogApiKey.isNotEmpty ? "configured" : "not configured"}',
    );
    print('Analytics: $enableAnalytics');
    print('Offline Sync: $enableOfflineSync');
    print('Cloud Backup: $enableCloudBackup');
    print('Multi-Store: $enableMultiStore');
    print('Advanced Reporting: $enableAdvancedReporting');
    print('PlayStation Mode: $enablePlaystationMode');
    print('Cafe Mode: $enableCafeMode');
    print('Debug Logging: $enableDebugLogging');
    print('Performance Monitoring: $enablePerformanceMonitoring');
    print('Crash Reporting: $enableCrashReporting');
    print('License Check Interval: ${licenseCheckIntervalHours}h');
    print('Print Server: $printServerBaseUrl');
    print('App Version: $appVersion+$buildNumber');
    print('==================');
  }
}
