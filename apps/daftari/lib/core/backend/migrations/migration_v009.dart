// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V009: Add device mapping tables (device->zone, device->floor, device->printers).
class MigrationV009 implements Migration {
  @override
  int get version => 9;

  @override
  String get description => 'Add device mapping tables: zone, floor, printers';

  @override
  Future<void> up() async {
    // In-memory device maps initialized (persisted via settings)
  }

  @override
  Future<void> down() async {
    // No-op: in-memory structures
  }
}
