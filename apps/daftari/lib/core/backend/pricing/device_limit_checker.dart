// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'pricing_tiers.dart';

/// Checks device limits against pricing tier limits.
class DeviceLimitChecker {
  /// Checks if a new device can be added for the given tenant.
  ///
  /// Returns true if the current device count is less than the maximum
  /// allowed for the tier, false otherwise.
  static bool checkDeviceLimit({
    required int currentCount,
    required int maxDevices,
  }) {
    return currentCount < maxDevices;
  }

  /// Returns the maximum number of devices allowed for a pricing tier.
  static int getMaxDevices(PricingTiers tier) {
    return tier.maxDevices;
  }
}
