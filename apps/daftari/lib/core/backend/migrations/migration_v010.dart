// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V010: Add rooms table for dining/service rooms.
class MigrationV010 implements Migration {
  @override
  int get version => 10;

  @override
  String get description => 'Add rooms table with zone and floor references';

  @override
  Future<void> up() async {
    // Rooms map initialized in DatabaseSchema
  }

  @override
  Future<void> down() async {
    // No-op: in-memory structure
  }
}
