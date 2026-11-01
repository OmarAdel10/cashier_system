// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V006: Add tables, table_rounds, and table_order_lines boxes for cafe/restaurant.
class MigrationV006 implements Migration {
  @override
  int get version => 6;

  @override
  String get description =>
      'Add tables, table_rounds, table_order_lines for table management';

  @override
  Future<void> up() async {
    // Table management boxes created
  }

  @override
  Future<void> down() async {
    // No-op: boxes managed by HiveBoxes
  }
}
