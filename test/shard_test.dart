import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/backend/sharding/shard_manager.dart';

void main() {
  group('ShardManager thresholds', () {
    test('per-tenant soft limit is 100MB', () {
      expect(ShardManager.tenantSoftLimitBytes, equals(100 * 1024 * 1024));
    });

    test('per-tenant hard limit is 300MB', () {
      expect(ShardManager.tenantHardLimitBytes, equals(300 * 1024 * 1024));
    });

    test('total DB soft limit is 600MB', () {
      expect(ShardManager.totalDbSoftLimitBytes, equals(600 * 1024 * 1024));
    });

    test('total DB hard limit is 800MB', () {
      expect(ShardManager.totalDbHardLimitBytes, equals(800 * 1024 * 1024));
    });

    test('single-tenant split threshold is 1GB', () {
      expect(
        ShardManager.singleTenantSplitThresholdBytes,
        equals(1024 * 1024 * 1024),
      );
    });
  });

  group('checkTenantLimit', () {
    test('below soft limit returns ok', () {
      expect(
        ShardManager.checkTenantLimit('t1', 50 * 1024 * 1024),
        equals(ShardLimitStatus.ok),
      );
    });

    test('at soft limit still ok (boundary)', () {
      expect(
        ShardManager.checkTenantLimit('t1', ShardManager.tenantSoftLimitBytes),
        equals(ShardLimitStatus.ok),
      );
    });

    test('above soft limit returns softExceeded', () {
      expect(
        ShardManager.checkTenantLimit(
          't1',
          ShardManager.tenantSoftLimitBytes + 1,
        ),
        equals(ShardLimitStatus.softExceeded),
      );
    });

    test('at hard limit returns softExceeded (boundary)', () {
      expect(
        ShardManager.checkTenantLimit('t1', ShardManager.tenantHardLimitBytes),
        equals(ShardLimitStatus.softExceeded),
      );
    });

    test('above hard limit returns hardExceeded', () {
      expect(
        ShardManager.checkTenantLimit(
          't1',
          ShardManager.tenantHardLimitBytes + 1,
        ),
        equals(ShardLimitStatus.hardExceeded),
      );
    });

    test('empty tenantId throws', () {
      expect(() => ShardManager.checkTenantLimit('', 10), throwsArgumentError);
      expect(
        () => ShardManager.checkTenantLimit('  ', 10),
        throwsArgumentError,
      );
    });

    test('negative bytes throws', () {
      expect(
        () => ShardManager.checkTenantLimit('t1', -1),
        throwsArgumentError,
      );
    });
  });

  group('checkTotalDbLimit', () {
    test('below soft limit returns ok', () {
      expect(
        ShardManager.checkTotalDbLimit(100 * 1024 * 1024),
        equals(ShardLimitStatus.ok),
      );
    });

    test('above soft limit returns softExceeded', () {
      expect(
        ShardManager.checkTotalDbLimit(ShardManager.totalDbSoftLimitBytes + 1),
        equals(ShardLimitStatus.softExceeded),
      );
    });

    test('above hard limit returns hardExceeded', () {
      expect(
        ShardManager.checkTotalDbLimit(ShardManager.totalDbHardLimitBytes + 1),
        equals(ShardLimitStatus.hardExceeded),
      );
    });

    test('negative bytes throws', () {
      expect(() => ShardManager.checkTotalDbLimit(-1), throwsArgumentError);
    });
  });

  group('split-across-DBs', () {
    test('at 1GB does not need split (boundary)', () {
      expect(
        ShardManager.needsSplitAcrossDbs(
          ShardManager.singleTenantSplitThresholdBytes,
        ),
        isFalse,
      );
    });

    test('above 1GB needs split', () {
      expect(
        ShardManager.needsSplitAcrossDbs(
          ShardManager.singleTenantSplitThresholdBytes + 1,
        ),
        isTrue,
      );
    });

    test('negative bytes throws', () {
      expect(() => ShardManager.needsSplitAcrossDbs(-1), throwsArgumentError);
    });
  });
}
