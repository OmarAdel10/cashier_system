// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V011: Add shard manager thresholds configuration.
class MigrationV011 implements Migration {
  @override
  int get version => 11;

  @override
  String get description => 'Add shard manager tiered thresholds configuration';

  @override
  Future<void> up() async {
    // ShardManager constants initialized
  }

  @override
  Future<void> down() async {
    // No-op: constants
  }
}
