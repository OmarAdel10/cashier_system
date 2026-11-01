// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V003: Add receipts and refunds boxes (lazy boxes for large payloads).
class MigrationV003 implements Migration {
  @override
  int get version => 3;

  @override
  String get description =>
      'Add receipts and refunds lazy boxes for transaction history';

  @override
  Future<void> up() async {
    // Receipts and refunds boxes created as LazyBoxes
  }

  @override
  Future<void> down() async {
    // No-op: boxes managed by HiveBoxes
  }
}
