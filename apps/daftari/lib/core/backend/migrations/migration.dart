// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Base interface for all database migrations.
abstract class Migration {
  /// Migration version number (1, 2, 3, ...).
  int get version;

  /// Human-readable description of what this migration does.
  String get description;

  /// Applies the migration (forward).
  Future<void> up();

  /// Reverts the migration (backward).
  Future<void> down();
}
