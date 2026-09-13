/// Flavor configuration for Daftari POS.
///
/// Supports multiple build flavors:
/// - `development` (dev) - Development builds with debug features
/// - `staging` (stg) - Staging builds for QA/testing
/// - `production` (prod) - Production releases
/// - `playstore` - Google Play Store builds
/// - `microsoft-store` - Microsoft Store builds
/// - `fdroid` - F-Droid builds
/// - `github-release` - GitHub Release builds
/// - `desktop-dev` - Desktop development builds
/// - `desktop-prod` - Desktop production builds
enum Flavor {
  development,
  staging,
  production,
  playstore,
  microsoftStore,
  fdroid,
  githubRelease,
  desktopDev,
  desktopProd,
}

/// Configuration values that vary by flavor.
class FlavorConfig {
  /// Current flavor (set at build time via --dart-define).
  static late final Flavor flavor;

  /// Application name suffix for this flavor.
  static late final String appNameSuffix;

  /// Bundle ID / Package name suffix.
  static late final String bundleIdSuffix;

  /// Base API URL for this flavor.
  static late final String apiBaseUrl;

  /// Firebase project ID for this flavor.
  static late final String firebaseProjectId;

  /// Turso database URL for this flavor.
  static late final String tursoDatabaseUrl;

  /// PostHog API key for this flavor.
  static late final String posthogApiKey;

  /// PostHog host for this flavor.
  static late final String posthogHost;

  /// Enable debug logging.
  static late final bool enableDebugLogging;

  /// Enable performance monitoring.
  static late final bool enablePerformanceMonitoring;

  /// Enable crash reporting.
  static late final bool enableCrashReporting;

  /// License check interval (hours).
  static late final int licenseCheckIntervalHours;

  /// Print server port.
  static late final int printServerPort;

  /// Analytics opt-out default.
  static late final bool analyticsOptOutDefault;

  /// Feature flags
  static late final bool enableOfflineSync;
  static late final bool enableCloudBackup;
  static late final bool enableMultiStore;
  static late final bool enableAdvancedReporting;
  static late final bool enablePlaystationMode;
  static late final bool enableCafeMode;

  /// Initialize flavor configuration from dart-defines.
  ///
  /// Call this once at app startup before using any FlavorConfig values.
  static void initialize({
    required Flavor flavor,
    required String appNameSuffix,
    required String bundleIdSuffix,
    required String apiBaseUrl,
    required String firebaseProjectId,
    required String tursoDatabaseUrl,
    required String posthogApiKey,
    required String posthogHost,
    required bool enableDebugLogging,
    required bool enablePerformanceMonitoring,
    required bool enableCrashReporting,
    required int licenseCheckIntervalHours,
    required int printServerPort,
    required bool analyticsOptOutDefault,
    required bool enableOfflineSync,
    required bool enableCloudBackup,
    required bool enableMultiStore,
    required bool enableAdvancedReporting,
    required bool enablePlaystationMode,
    required bool enableCafeMode,
  }) {
    FlavorConfig.flavor = flavor;
    FlavorConfig.appNameSuffix = appNameSuffix;
    FlavorConfig.bundleIdSuffix = bundleIdSuffix;
    FlavorConfig.apiBaseUrl = apiBaseUrl;
    FlavorConfig.firebaseProjectId = firebaseProjectId;
    FlavorConfig.tursoDatabaseUrl = tursoDatabaseUrl;
    FlavorConfig.posthogApiKey = posthogApiKey;
    FlavorConfig.posthogHost = posthogHost;
    FlavorConfig.enableDebugLogging = enableDebugLogging;
    FlavorConfig.enablePerformanceMonitoring = enablePerformanceMonitoring;
    FlavorConfig.enableCrashReporting = enableCrashReporting;
    FlavorConfig.licenseCheckIntervalHours = licenseCheckIntervalHours;
    FlavorConfig.printServerPort = printServerPort;
    FlavorConfig.analyticsOptOutDefault = analyticsOptOutDefault;
    FlavorConfig.enableOfflineSync = enableOfflineSync;
    FlavorConfig.enableCloudBackup = enableCloudBackup;
    FlavorConfig.enableMultiStore = enableMultiStore;
    FlavorConfig.enableAdvancedReporting = enableAdvancedReporting;
    FlavorConfig.enablePlaystationMode = enablePlaystationMode;
    FlavorConfig.enableCafeMode = enableCafeMode;
  }

  /// Get display name for the current flavor.
  static String get displayName {
    switch (flavor) {
      case Flavor.development:
        return 'Daftari POS Dev';
      case Flavor.staging:
        return 'Daftari POS Staging';
      case Flavor.production:
        return 'Daftari POS';
      case Flavor.playstore:
        return 'Daftari POS';
      case Flavor.microsoftStore:
        return 'Daftari POS';
      case Flavor.fdroid:
        return 'Daftari POS';
      case Flavor.githubRelease:
        return 'Daftari POS';
      case Flavor.desktopDev:
        return 'Daftari POS Dev';
      case Flavor.desktopProd:
        return 'Daftari POS';
    }
  }

  /// Get full bundle identifier.
  static String get bundleId => 'com.daftari.pos$bundleIdSuffix';

  /// Check if current flavor is a production-like build.
  static bool get isProductionLike {
    return flavor == Flavor.production ||
        flavor == Flavor.playstore ||
        flavor == Flavor.microsoftStore ||
        flavor == Flavor.fdroid ||
        flavor == Flavor.githubRelease ||
        flavor == Flavor.desktopProd;
  }

  /// Check if current flavor is a development build.
  static bool get isDevelopment {
    return flavor == Flavor.development || flavor == Flavor.desktopDev;
  }

  /// Check if current flavor is a desktop build.
  static bool get isDesktop {
    return flavor == Flavor.desktopDev || flavor == Flavor.desktopProd;
  }

  /// Check if current flavor is a mobile build.
  static bool get isMobile {
    return !isDesktop;
  }

  /// Get flavor-specific asset path prefix.
  static String get assetPrefix {
    switch (flavor) {
      case Flavor.development:
      case Flavor.desktopDev:
        return 'assets/dev/';
      case Flavor.staging:
        return 'assets/stg/';
      default:
        return 'assets/prod/';
    }
  }
}
