// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V005: Add session_records and floor_zones boxes.
class MigrationV005 implements Migration {
  @override
  int get version => 5;

  @override
  String get description =>
      'Add session_records and floor_zones boxes for session tracking';

  @override
  Future<void> up() async {
    // Session records and floor zones boxes created
  }

  @override
  Future<void> down() async {
    // No-op: boxes managed by HiveBoxes
  }
}
