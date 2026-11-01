// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V013: Add schema version tracking and migration framework.
class MigrationV013 implements Migration {
  @override
  int get version => 13;

  @override
  String get description =>
      'Add schema version tracking and migration framework';

  @override
  Future<void> up() async {
    // DatabaseSchema.version = 13, MigrationRunner available
  }

  @override
  Future<void> down() async {
    // No-op: framework code
  }
}
