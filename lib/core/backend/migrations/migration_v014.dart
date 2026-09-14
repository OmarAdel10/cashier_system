// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V014: Final schema version bump to 14 with all features complete.
class MigrationV014 implements Migration {
  @override
  int get version => 14;

  @override
  String get description =>
      'Final schema version 14: all 16 boxes, device maps, rooms, audit log, sharding';

  @override
  Future<void> up() async {
    // DatabaseSchema.version = 14
  }

  @override
  Future<void> down() async {
    // No-op: final version
  }
}
