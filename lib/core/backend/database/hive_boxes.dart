// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:cashier_system/core/backend/database/database_schema.dart';

/// Hive box open/registration helpers matching [DatabaseSchema].
///
/// All opens require the app [HiveAesCipher] (same cipher used in `main.dart`
/// via `encryptionCipher:`) and recover from corrupt boxes by deleting from
/// disk and retrying, mirroring `openBoxWithRecovery`/`openLazyBoxWithRecovery`
/// in `lib/main.dart`. Regular models use [Box]; large/append-only payloads
/// ([DatabaseSchema.lazyBoxNames]) use [LazyBox].
class HiveBoxes {
  /// All box names from the schema (must stay 16 per spec §5j).
  static List<String> get allBoxNames => DatabaseSchema.boxNames;

  /// Opens the regular [Box] named [name] with [cipher].
  ///
  /// Throws [ArgumentError] when [name] is not part of the schema or when it
  /// is a LazyBox (use [openLazyBox] for those).
  static Future<Box<T>> openBox<T>(
    String name, {
    required HiveAesCipher cipher,
  }) {
    if (!DatabaseSchema.boxNames.contains(name)) {
      throw ArgumentError('Unknown Hive box: $name');
    }
    if (DatabaseSchema.isLazyBox(name)) {
      throw ArgumentError('Box "$name" is a LazyBox; use openLazyBox');
    }
    return openBoxWithRecovery<T>(name, cipher: cipher);
  }

  /// Opens the [LazyBox] named [name] with [cipher].
  ///
  /// Throws [ArgumentError] when [name] is not part of the schema or when it
  /// is a regular Box (use [openBox] for those).
  static Future<LazyBox<T>> openLazyBox<T>(
    String name, {
    required HiveAesCipher cipher,
  }) {
    if (!DatabaseSchema.boxNames.contains(name)) {
      throw ArgumentError('Unknown Hive box: $name');
    }
    if (!DatabaseSchema.isLazyBox(name)) {
      throw ArgumentError('Box "$name" is a regular Box; use openBox');
    }
    return openLazyBoxWithRecovery<T>(name, cipher: cipher);
  }

  /// Opens a regular box with corrupt-box recovery (delete + retry).
  static Future<Box<T>> openBoxWithRecovery<T>(
    String name, {
    required HiveAesCipher cipher,
  }) async {
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (e) {
      debugPrint('[Hive] Box "$name" is corrupt ($e); deleting and reopening.');
      await Hive.deleteBoxFromDisk(name);
      try {
        return await Hive.openBox<T>(name, encryptionCipher: cipher);
      } catch (e2) {
        debugPrint(
          '[Hive] Box "$name" reopen failed ($e2); retrying once more.',
        );
        await Hive.deleteBoxFromDisk(name);
        return Hive.openBox<T>(name, encryptionCipher: cipher);
      }
    }
  }

  /// Opens a lazy box with corrupt-box recovery (delete + retry).
  static Future<LazyBox<T>> openLazyBoxWithRecovery<T>(
    String name, {
    required HiveAesCipher cipher,
  }) async {
    try {
      return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
    } catch (e) {
      debugPrint(
        '[Hive] Lazy box "$name" is corrupt ($e); deleting and reopening.',
      );
      await Hive.deleteBoxFromDisk(name);
      try {
        return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
      } catch (e2) {
        debugPrint(
          '[Hive] Lazy box "$name" reopen failed ($e2); retrying once more.',
        );
        await Hive.deleteBoxFromDisk(name);
        return Hive.openLazyBox<T>(name, encryptionCipher: cipher);
      }
    }
  }

  /// Opens every box in [DatabaseSchema.boxNames] in order, using the
  /// correct Box/LazyBox opener per [DatabaseSchema.isLazyBox].
  static Future<void> openAll({required HiveAesCipher cipher}) async {
    for (final name in DatabaseSchema.boxNames) {
      if (DatabaseSchema.isLazyBox(name)) {
        await openLazyBoxWithRecovery<dynamic>(name, cipher: cipher);
      } else {
        await openBoxWithRecovery<dynamic>(name, cipher: cipher);
      }
    }
  }

  /// Closes all open Hive boxes.
  static Future<void> closeAll() => Hive.close();

  /// True when [name] is a known schema box and currently open.
  static bool isOpen(String name) {
    if (!DatabaseSchema.boxNames.contains(name)) return false;
    return Hive.isBoxOpen(name);
  }
}
