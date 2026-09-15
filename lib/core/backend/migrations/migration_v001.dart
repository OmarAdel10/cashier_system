// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V001: Initialize core Hive boxes for authentication and shifts.
class MigrationV001 implements Migration {
  @override
  int get version => 1;

  @override
  String get description =>
      'Initialize core Hive boxes: auth_users, shifts, active_shifts';

  @override
  Future<void> up() async {
    // Core boxes created by HiveBoxes.init()
    // This migration marks the baseline schema version
  }

  @override
  Future<void> down() async {
    // No-op: baseline migration cannot be rolled back
  }
}
