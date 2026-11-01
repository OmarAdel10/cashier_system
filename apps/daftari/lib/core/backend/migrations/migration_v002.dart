// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V002: Add settings and inventory boxes.
class MigrationV002 implements Migration {
  @override
  int get version => 2;

  @override
  String get description => 'Add settings and inventory Hive boxes';

  @override
  Future<void> up() async {
    // Settings and inventory boxes created by HiveBoxes.init()
  }

  @override
  Future<void> down() async {
    // No-op: boxes managed by HiveBoxes
  }
}
