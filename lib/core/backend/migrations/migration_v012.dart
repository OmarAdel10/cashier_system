// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V012: Add audit log convergence bridge for buffer persistence.
class MigrationV012 implements Migration {
  @override
  int get version => 12;

  @override
  String get description =>
      'Add audit log convergence bridge for buffer/persisted sync';

  @override
  Future<void> up() async {
    // AuditLogConvergenceBridge initialized
  }

  @override
  Future<void> down() async {
    // No-op: in-memory bridge
  }
}
