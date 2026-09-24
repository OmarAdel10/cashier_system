// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Build flavors for Daftari POS.
///
/// Four flavors representing different app configurations:
/// - `local`: Desktop only, no cloud sync, license required
/// - `cloud`: Desktop + web (prod), cloud sync via Turso, tier-dependent devices
/// - `landing`: Web (Jaspr), no auth/license, marketing site
/// - `admin`: Flutter web WASM, full admin dashboard, cloud sync
enum AppFlavor { local, cloud, landing, admin }

/// Configuration values that vary by flavor.
class FlavorConfig {
  /// Current flavor (set at build time via --dart-define).
  static late final AppFlavor flavor;

  /// Application name.
  static late final String appName;

  /// Whether this flavor requires authentication.
  static late final bool requiresAuth;

  /// Whether this flavor requires a license.
  static late final bool requiresLicense;

  /// Whether license is auto-granted on payment.
  static late final bool autoLicenseOnPayment;

  /// Whether this flavor has cloud sync via Turso.
  static late final bool hasCloudSync;

  /// Whether this flavor has admin dashboard.
  static late final bool hasAdminDashboard;

  /// Whether this flavor has local printing.
  static late final bool hasLocalPrinting;

  /// Whether this flavor has push notifications.
  static late final bool hasPushNotifications;

  /// Maximum devices allowed (0 = unlimited or N/A).
  static late final int maxDevices;

  /// Supported platforms for this flavor.
  static late final List<String> supportedPlatforms;

  /// Initializes flavor configuration from dart-defines.
  static void initializeFromEnv() {
    const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'local');
    final config = _createFromEnv(flavorName);
    FlavorConfig.flavor = config.flavor;
    FlavorConfig.appName = config.appName;
    FlavorConfig.requiresAuth = config.requiresAuth;
    FlavorConfig.requiresLicense = config.requiresLicense;
    FlavorConfig.autoLicenseOnPayment = config.autoLicenseOnPayment;
    FlavorConfig.hasCloudSync = config.hasCloudSync;
    FlavorConfig.hasAdminDashboard = config.hasAdminDashboard;
    FlavorConfig.hasLocalPrinting = config.hasLocalPrinting;
    FlavorConfig.hasPushNotifications = config.hasPushNotifications;
    FlavorConfig.maxDevices = config.maxDevices;
    FlavorConfig.supportedPlatforms = config.supportedPlatforms;
  }

  static _FlavorConfigData _createFromEnv(String flavorName) {
    return switch (flavorName) {
      'local' => _FlavorConfigData._(
        flavor: AppFlavor.local,
        appName: 'Daftari',
        requiresAuth: true,
        requiresLicense: true,
        autoLicenseOnPayment: true,
        hasCloudSync: false,
        hasAdminDashboard: false,
        hasLocalPrinting: true,
        hasPushNotifications: true,
        maxDevices: 1,
        supportedPlatforms: ['windows', 'linux'],
      ),
      'cloud' => _FlavorConfigData._(
        flavor: AppFlavor.cloud,
        appName: 'Daftari',
        requiresAuth: true,
        requiresLicense: true,
        autoLicenseOnPayment: true,
        hasCloudSync: true,
        hasAdminDashboard: false,
        hasLocalPrinting: true,
        hasPushNotifications: true,
        maxDevices: 4,
        supportedPlatforms: ['windows', 'linux'],
      ),
      'landing' => _FlavorConfigData._(
        flavor: AppFlavor.landing,
        appName: 'Daftari',
        requiresAuth: false,
        requiresLicense: false,
        autoLicenseOnPayment: false,
        hasCloudSync: false,
        hasAdminDashboard: false,
        hasLocalPrinting: false,
        hasPushNotifications: false,
        maxDevices: 0,
        supportedPlatforms: ['web'],
      ),
      'admin' => _FlavorConfigData._(
        flavor: AppFlavor.admin,
        appName: 'Daftari Admin',
        requiresAuth: true,
        requiresLicense: false,
        autoLicenseOnPayment: false,
        hasCloudSync: true,
        hasAdminDashboard: true,
        hasLocalPrinting: false,
        hasPushNotifications: false,
        maxDevices: 0,
        supportedPlatforms: ['web'],
      ),
      _ => throw Exception('Unknown flavor: $flavorName'),
    };
  }

  // No instance constructor - all members are static
  FlavorConfig._();
}

class _FlavorConfigData {
  final AppFlavor flavor;
  final String appName;
  final bool requiresAuth;
  final bool requiresLicense;
  final bool autoLicenseOnPayment;
  final bool hasCloudSync;
  final bool hasAdminDashboard;
  final bool hasLocalPrinting;
  final bool hasPushNotifications;
  final int maxDevices;
  final List<String> supportedPlatforms;

  const _FlavorConfigData._({
    required this.flavor,
    required this.appName,
    required this.requiresAuth,
    required this.requiresLicense,
    required this.autoLicenseOnPayment,
    required this.hasCloudSync,
    required this.hasAdminDashboard,
    required this.hasLocalPrinting,
    required this.hasPushNotifications,
    required this.maxDevices,
    required this.supportedPlatforms,
  });
}
