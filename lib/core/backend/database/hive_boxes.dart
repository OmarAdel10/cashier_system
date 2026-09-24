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
    _checkRegularBox(name);
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
    _checkLazyBox(name);
    return openLazyBoxWithRecovery<T>(name, cipher: cipher);
  }

  /// Validates [name] against the schema for a regular [Box] open.
  static void _checkRegularBox(String name) {
    if (!DatabaseSchema.boxNames.contains(name)) {
      throw ArgumentError('Unknown Hive box: $name');
    }
    if (DatabaseSchema.isLazyBox(name)) {
      throw ArgumentError('Box "$name" is a LazyBox; use openLazyBox');
    }
  }

  /// Validates [name] against the schema for a [LazyBox] open.
  static void _checkLazyBox(String name) {
    if (!DatabaseSchema.boxNames.contains(name)) {
      throw ArgumentError('Unknown Hive box: $name');
    }
    if (!DatabaseSchema.isLazyBox(name)) {
      throw ArgumentError('Box "$name" is a regular Box; use openBox');
    }
  }

  /// Opens a regular box with corrupt-box recovery (delete + single retry).
  ///
  /// WARNING: recovery deletes the box from disk, so a wrong-cipher open
  /// also wipes data. Callers must ensure the correct cipher (a key loss
  /// must never cascade: do not loop [openAll] blindly after a decrypt
  /// failure). Mirrors `openBoxWithRecovery` in `lib/main.dart`.
  static Future<Box<T>> openBoxWithRecovery<T>(
    String name, {
    required HiveAesCipher cipher,
  }) async {
    _checkRegularBox(name);
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (_) {
      debugPrint('[Hive] Box "$name" open failed; deleting and reopening.');
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Opens a lazy box with corrupt-box recovery (delete + single retry).
  ///
  /// Same wrong-cipher data-loss caveat as [openBoxWithRecovery].
  static Future<LazyBox<T>> openLazyBoxWithRecovery<T>(
    String name, {
    required HiveAesCipher cipher,
  }) async {
    _checkLazyBox(name);
    try {
      return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
    } catch (_) {
      debugPrint(
        '[Hive] Lazy box "$name" open failed; deleting and reopening.',
      );
      await Hive.deleteBoxFromDisk(name);
      return Hive.openLazyBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Opens every box in [DatabaseSchema.boxNames] in order, using the
  /// correct Box/LazyBox opener per [DatabaseSchema.isLazyBox].
  ///
  /// Boxes open as `<dynamic>`; repositories cast to their model types.
  /// A throw aborts the loop, leaving earlier boxes open (caller retries
  /// or closes via [closeAll]). Do not call after a decrypt failure:
  /// every box would delete + reopen empty, wiping all 16 boxes.
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
