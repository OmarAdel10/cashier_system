// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:hive/hive.dart';

import 'package:cashier_system/core/backend/database/database_schema.dart';

/// Hive box open/registration helpers matching [DatabaseSchema].
class HiveBoxes {
  /// All box names from the schema (must stay 19).
  static List<String> get allBoxNames => DatabaseSchema.boxNames;

  /// Opens the box named [name].
  ///
  /// Throws [ArgumentError] when [name] is not part of the schema.
  static Future<Box> openBox(String name) {
    if (!DatabaseSchema.boxNames.contains(name)) {
      throw ArgumentError('Unknown Hive box: $name');
    }
    return Hive.openBox(name);
  }

  /// Opens every box in [DatabaseSchema.boxNames] in order.
  static Future<List<Box>> openAll() async {
    final boxes = <Box>[];
    for (final name in DatabaseSchema.boxNames) {
      boxes.add(await Hive.openBox(name));
    }
    return boxes;
  }

  /// Closes all open Hive boxes.
  static Future<void> closeAll() => Hive.close();

  /// True when [name] is a known schema box and currently open.
  static bool isOpen(String name) => Hive.isBoxOpen(name);
}
