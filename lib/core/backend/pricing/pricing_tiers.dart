// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Pricing tiers for Daftari POS system.
///
/// Each tier defines device limits and feature flags.
enum PricingTiers {
  starter(
    name: 'Starter',
    maxDevices: 1,
    hasAdvancedReports: false,
    hasMultiLocation: false,
    hasApiAccess: false,
    prioritySupport: false,
  ),
  professional(
    name: 'Professional',
    maxDevices: 2,
    hasAdvancedReports: true,
    hasMultiLocation: false,
    hasApiAccess: true,
    prioritySupport: false,
  ),
  business(
    name: 'Business',
    maxDevices: 4,
    hasAdvancedReports: true,
    hasMultiLocation: true,
    hasApiAccess: true,
    prioritySupport: true,
  );

  const PricingTiers({
    required this.name,
    required this.maxDevices,
    required this.hasAdvancedReports,
    required this.hasMultiLocation,
    required this.hasApiAccess,
    required this.prioritySupport,
  });

  final String name;
  final int maxDevices;
  final bool hasAdvancedReports;
  final bool hasMultiLocation;
  final bool hasApiAccess;
  final bool prioritySupport;

  /// Returns the tier from a string name.
  static PricingTiers fromString(String name) {
    return PricingTiers.values.firstWhere(
      (tier) => tier.name.toLowerCase() == name.toLowerCase(),
      orElse: () => PricingTiers.starter,
    );
  }

  /// Returns all tiers ordered by device limit.
  static List<PricingTiers> get orderedByDevices => [
    PricingTiers.starter,
    PricingTiers.professional,
    PricingTiers.business,
  ];
}
