// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'migration.dart';

/// V008: Add expenses box for expense tracking.
class MigrationV008 implements Migration {
  @override
  int get version => 8;

  @override
  String get description => 'Add expenses lazy box for expense tracking';

  @override
  Future<void> up() async {
    // Expenses box created as LazyBox
  }

  @override
  Future<void> down() async {
    // No-op: box managed by HiveBoxes
  }
}
