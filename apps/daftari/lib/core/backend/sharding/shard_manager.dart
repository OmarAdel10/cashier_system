// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Tiered sharding thresholds and limit checks.
///
/// Pure-Dart so it stays unit-testable without Hive initialization.
/// Builds on Task 4 DatabaseSchema without altering schema behavior.
enum ShardLimitStatus {
  /// Within soft limit: normal operation.
  ok,

  /// Above soft limit, at or below hard limit: warn / plan split.
  softExceeded,

  /// Above hard limit: block writes / force split.
  hardExceeded,
}

/// Tiered per-tenant and total-DB size guardrails.
class ShardManager {
  const ShardManager._();

  /// Per-tenant soft limit: 100MB (warn).
  static const int tenantSoftLimitBytes = 100 * 1024 * 1024;

  /// Per-tenant hard limit: 300MB (block).
  static const int tenantHardLimitBytes = 300 * 1024 * 1024;

  /// Total DB soft limit: 600MB (~75% of quota, warn).
  static const int totalDbSoftLimitBytes = 600 * 1024 * 1024;

  /// Total DB hard limit: 800MB (~80% of quota, block).
  static const int totalDbHardLimitBytes = 800 * 1024 * 1024;

  /// Single tenant above 1GB must split across DBs.
  static const int singleTenantSplitThresholdBytes = 1024 * 1024 * 1024;

  static ShardLimitStatus _classify(int bytes, int soft, int hard) {
    if (bytes <= soft) return ShardLimitStatus.ok;
    if (bytes <= hard) return ShardLimitStatus.softExceeded;
    return ShardLimitStatus.hardExceeded;
  }

  static void _requireNonNegative(int bytes) {
    if (bytes < 0) {
      throw ArgumentError('bytes cannot be negative: $bytes');
    }
  }

  /// Checks a tenant's usage against per-tenant tiered thresholds.
  static ShardLimitStatus checkTenantLimit(String tenantId, int bytes) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('tenantId cannot be empty');
    }
    _requireNonNegative(bytes);
    return _classify(bytes, tenantSoftLimitBytes, tenantHardLimitBytes);
  }

  /// Checks total DB usage against total-DB tiered thresholds.
  static ShardLimitStatus checkTotalDbLimit(int bytes) {
    _requireNonNegative(bytes);
    return _classify(bytes, totalDbSoftLimitBytes, totalDbHardLimitBytes);
  }

  /// True when a single tenant's usage exceeds 1GB and must split across DBs.
  ///
  /// Boundary: exactly 1GB does NOT need a split; only strictly greater does.
  static bool needsSplitAcrossDbs(int bytes) {
    _requireNonNegative(bytes);
    return bytes > singleTenantSplitThresholdBytes;
  }
}
