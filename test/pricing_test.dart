import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/backend/pricing/pricing_tiers.dart';
import 'package:cashier_system/core/backend/pricing/device_limit_checker.dart';

void main() {
  group('PricingTiers', () {
    test('Starter tier has 1 device limit', () {
      expect(PricingTiers.starter.maxDevices, equals(1));
    });

    test('Professional tier has 2 device limit', () {
      expect(PricingTiers.professional.maxDevices, equals(2));
    });

    test('Business tier has 4 device limit', () {
      expect(PricingTiers.business.maxDevices, equals(4));
    });

    test('tiers have correct feature flags', () {
      expect(PricingTiers.starter.hasAdvancedReports, isFalse);
      expect(PricingTiers.professional.hasAdvancedReports, isTrue);
      expect(PricingTiers.business.hasAdvancedReports, isTrue);
    });
  });

  group('DeviceLimitChecker', () {
    test('allows device when under limit', () {
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 0, maxDevices: 1), isTrue);
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 1, maxDevices: 2), isTrue);
    });

    test('rejects device when at limit', () {
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 1, maxDevices: 1), isFalse);
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 2, maxDevices: 2), isFalse);
    });

    test('rejects device when over limit', () {
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 2, maxDevices: 1), isFalse);
      expect(DeviceLimitChecker.checkDeviceLimit(currentCount: 3, maxDevices: 2), isFalse);
    });

    test('getMaxDevices returns correct values', () {
      expect(DeviceLimitChecker.getMaxDevices(PricingTiers.starter), equals(1));
      expect(DeviceLimitChecker.getMaxDevices(PricingTiers.professional), equals(2));
      expect(DeviceLimitChecker.getMaxDevices(PricingTiers.business), equals(4));
    });
  });
}
