// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V004: Add product_categories and stations boxes.
class MigrationV004 implements Migration {
  @override
  int get version => 4;

  @override
  String get description =>
      'Add product_categories and stations boxes for catalog management';

  @override
  Future<void> up() async {
    // Product categories and stations boxes created
  }

  @override
  Future<void> down() async {
    // No-op: boxes managed by HiveBoxes
  }
}
