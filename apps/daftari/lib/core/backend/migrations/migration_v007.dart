// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V007: Add audit_log box with 90-day retention policy.
class MigrationV007 implements Migration {
  @override
  int get version => 7;

  @override
  String get description => 'Add audit_log lazy box with 90-day retention';

  @override
  Future<void> up() async {
    // Audit log box created as LazyBox with JSON string entries
  }

  @override
  Future<void> down() async {
    // No-op: box managed by HiveBoxes
  }
}
