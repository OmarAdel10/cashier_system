import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/licensing/domain/enums/license_status.dart';
import 'core/licensing/engine/license_engine.dart';
import 'core/printing/print_server_factory.dart';
import 'core/printing/print_server_manager.dart';
import 'core/printing/print_server_manager_linux.dart';
import 'core/printing/print_server_refresh.dart';
import 'features/auth/data/models/app_user_model.dart';
import 'features/auth/data/models/app_shift_model.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/shifts_repository_impl.dart';
import 'features/inventory/data/models/app_product_model.dart';
import 'features/inventory/data/repositories/inventory_repository.dart';
import 'features/receipts/data/models/app_receipt_model.dart';
import 'features/receipts/data/models/app_refund_model.dart';
import 'features/checkout/data/models/app_station_model.dart';
import 'features/checkout/data/models/app_session_record_model.dart';
import 'features/checkout/data/models/app_zone_model.dart';
import 'features/checkout/data/models/app_table_model.dart';
import 'features/checkout/data/models/app_table_round_model.dart';
import 'features/checkout/data/models/app_table_order_line_model.dart';
import 'features/receipts/data/models/receipt_item_adapter.dart';
import 'features/expenses/data/models/app_expense_model.dart';
import 'core/audit/audit_service.dart';
import 'features/settings/data/models/app_settings_model.dart';
import 'features/settings/data/repositories/settings_repository.dart';

Future<void> ensureKioskFullscreen() async {
  await windowManager.ensureInitialized();
  const kioskOptions = WindowOptions(
    fullScreen: true,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );
  await windowManager.waitUntilReadyToShow(kioskOptions, () async {
    await windowManager.show();
    await windowManager.setFullScreen(true);
  });
}

Future<Box<T>> openBoxWithRecovery<T>(
  String name, {
  required HiveAesCipher cipher,
}) async {
  try {
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  } catch (e) {
    debugPrint('[Hive] Box "$name" is corrupt ($e); deleting and reopening.');
    await _cleanupAndRetry(name);
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (e2) {
      debugPrint('[Hive] Box "$name" reopen failed ($e2); retrying once more.');
      await _cleanupAndRetry(name);
      return Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }
}

Future<LazyBox<T>> openLazyBoxWithRecovery<T>(
  String name, {
  required HiveAesCipher cipher,
}) async {
  try {
    return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
  } catch (e) {
    debugPrint(
      '[Hive] Lazy box "$name" is corrupt ($e); deleting and reopening.',
    );
    await _cleanupAndRetry(name);
    try {
      return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
    } catch (e2) {
      debugPrint(
        '[Hive] Lazy box "$name" reopen failed ($e2); retrying once more.',
      );
      await _cleanupAndRetry(name);
      return Hive.openLazyBox<T>(name, encryptionCipher: cipher);
    }
  }
}

Future<void> _cleanupAndRetry(String name) async {
  // Deleting too fast can race the failed box's un-awaited close() which may
  // still hold the file open on Windows; retry with delays.
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      await Hive.deleteBoxFromDisk(name);
      break;
    } catch (e) {
      debugPrint(
        '[Hive] deleteBoxFromDisk("$name") attempt ${attempt + 1} failed: $e',
      );
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // Try to delete stale lock file with retries (another process may still hold it)
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final docsDir = await getApplicationSupportDirectory();
      final lockFile = File('${docsDir.path}/$name.lock');
      if (await lockFile.exists()) {
        await lockFile.delete();
        debugPrint('[Hive] Deleted stale lock file: ${lockFile.path}');
        break;
      }
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}

Future<void> purgePoisonedFrames<T>(
  Box<T> box, {
  required bool Function() overreadDetected,
  required String name,
}) async {
  if (!overreadDetected()) return;
  debugPrint(
    '[Hive] Box "$name" contained legacy over-counted frames; '
    're-writing values to purge them.',
  );
  try {
    final entries = box.toMap();
    for (final entry in entries.entries) {
      await box.put(entry.key, entry.value);
    }
    await box.compact();
  } catch (e) {
    debugPrint('[Hive] Purge of "$name" failed ($e); continuing.');
  }
}

Future<bool> ensurePrintServerBuilt() async {
  final csproj = [
    'PrintServer',
    'PrintServer.csproj',
  ].join(Platform.pathSeparator);

  // No csproj in the working tree -> installed/production layout. The Inno
  // Setup installer ships its own server build and those machines never
  // have the .NET SDK, so never attempt a build (historical "skip
  // publishing" intent). Only succeed when an exe is actually on disk.
  if (!File(csproj).existsSync()) {
    for (final candidate in PrintServerManager.exeCandidates()) {
      if (File(candidate).existsSync()) return true;
    }
    return false;
  }

  // Dev layout: republish whenever the newest source is newer than every
  // existing PrintServer.exe, so new endpoints (e.g. /api/printing/save-pdf)
  // land on disk even when a stale exe is already present.
  final sourceFiles = <File>[];
  void collectSources(Directory dir) {
    for (final entry in dir.listSync(followLinks: false)) {
      if (entry is Directory) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name == 'bin' || name == 'obj') continue;
        collectSources(entry);
      } else if (entry is File) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.endsWith('.cs') ||
            name.endsWith('.csproj') ||
            name.endsWith('.ttf')) {
          sourceFiles.add(entry);
        }
      }
    }
  }

  collectSources(Directory('PrintServer'));
  DateTime? newestSourceModified;
  for (final file in sourceFiles) {
    final modified = file.lastModifiedSync();
    if (newestSourceModified == null ||
        modified.isAfter(newestSourceModified)) {
      newestSourceModified = modified;
    }
  }

  final candidateExes = <({String path, DateTime modified})>[];
  for (final candidate in PrintServerManager.exeCandidates()) {
    final exe = File(candidate);
    if (exe.existsSync()) {
      candidateExes.add((path: candidate, modified: exe.lastModifiedSync()));
    }
  }

  final action = decidePublish(
    csprojExists: File(csproj).existsSync(),
    newestSourceModified: newestSourceModified,
    candidateExes: candidateExes,
  );

  if (action == PrintServerBuildAction.none) {
    dev.log('[PrintServer] PrintServer.exe is up to date.');
    return true;
  }

  dev.log('[PrintServer] Publishing .NET project to runner debug folder...');

  final outputDir = [
    'build',
    'windows',
    'x64',
    'runner',
    'Debug',
  ].join(Platform.pathSeparator);

  final result = await Process.run('dotnet', [
    'publish',
    csproj,
    '-c',
    'Debug',
    '-o',
    outputDir,
  ]);

  if (result.exitCode != 0) {
    print('[PrintServer] Publish failed:\n${result.stderr}');
    return false;
  }

  print('[PrintServer] Publish succeeded');
  return true;
}

Future<bool> _ensurePrintServerLinuxBuilt() async {
  final csproj = [
    'PrintServer.Linux',
    'PrintServer.Linux.csproj',
  ].join(Platform.pathSeparator);

  // No csproj in the working tree -> installed/production layout.
  if (!File(csproj).existsSync()) {
    for (final candidate in PrintServerManagerLinux.exeCandidatesLinux()) {
      if (File(candidate).existsSync()) return true;
    }
    return false;
  }

  // Dev layout: publish self-contained linux-x64 binary
  dev.log('[PrintServer.Linux] Publishing .NET project to bundle folder...');

  final outputDir = [
    'build',
    'linux',
    'x64',
    'release',
    'bundle',
    'PrintServer',
  ].join(Platform.pathSeparator);

  final result = await Process.run('dotnet', [
    'publish',
    csproj,
    '-c',
    'Release',
    '-r',
    'linux-x64',
    '--self-contained',
    '-o',
    outputDir,
  ]);

  if (result.exitCode != 0) {
    print('[PrintServer.Linux] Publish failed:\n${result.stderr}');
    return false;
  }

  print('[PrintServer.Linux] Publish succeeded');
  return true;
}

Future<void> silentLicenseCheck(LicenseEngine engine) async {
  try {
    final status = await engine.verifyLicense();
    if (status == LicenseStatus.tampered) {
      debugPrint(
        '[Licensing] WARNING: License tampered or HWID mismatch detected.',
      );
    }
  } catch (e) {
    debugPrint('[Licensing] License check failed: $e');
  }
}

Future<void> main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[App] Unhandled Flutter error: ${details.exception}');
    debugPrint('${details.stack}');
  };

  await runZonedGuarded(_bootApp, (error, stackTrace) {
    debugPrint('[App] Uncaught async error: $error');
    debugPrint('$stackTrace');
  });
}

Future<void> _bootApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with a proper app data directory to avoid Documents folder issues
  // Use getApplicationSupportDirectory which returns AppData\Local\<app> on Windows
  final appSupportDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(appSupportDir.path);

  await ensureKioskFullscreen();

  Hive.registerAdapter(AppSettingsModelAdapter());
  Hive.registerAdapter(AppProductModelAdapter());
  Hive.registerAdapter(AppUserModelAdapter());
  Hive.registerAdapter(AppShiftModelAdapter());
  Hive.registerAdapter(AppReceiptModelAdapter());
  Hive.registerAdapter(AppRefundModelAdapter());
  Hive.registerAdapter(ReceiptItemAdapter());
  Hive.registerAdapter(AppStationModelAdapter());
  Hive.registerAdapter(AppSessionRecordModelAdapter());
  Hive.registerAdapter(AppZoneModelAdapter());
  Hive.registerAdapter(AppTableModelAdapter());
  Hive.registerAdapter(AppTableRoundModelAdapter());
  Hive.registerAdapter(AppTableOrderLineModelAdapter());
  Hive.registerAdapter(AppExpenseModelAdapter());

  final storage = FlutterSecureStorage();
  String? storedKey = await storage.read(key: 'hive_encryption_key');
  if (storedKey == null) {
    storedKey = base64Url.encode(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await storage.write(key: 'hive_encryption_key', value: storedKey);
  }
  final encryptionKey = base64.decode(storedKey);
  final cipher = HiveAesCipher(encryptionKey);

  AppSettingsModelAdapter.overreadDetected = false;
  final settingsBox = await openBoxWithRecovery<AppSettingsModel>(
    'settings',
    cipher: cipher,
  );
  await purgePoisonedFrames(
    settingsBox,
    name: 'settings',
    overreadDetected: () => AppSettingsModelAdapter.overreadDetected,
  );
  final inventoryBox = await openBoxWithRecovery<AppProductModel>(
    'inventory',
    cipher: cipher,
  );
  final authBox = await openBoxWithRecovery<AppUserModel>(
    'auth_users',
    cipher: cipher,
  );
  final shiftsBox = await openBoxWithRecovery<AppShiftModel>(
    'shifts',
    cipher: cipher,
  );
  final activeShiftsBox = await openBoxWithRecovery<String>(
    'active_shifts',
    cipher: cipher,
  );
  await openBoxWithRecovery<List>('product_categories', cipher: cipher);
  AppStationModelAdapter.overreadDetected = false;
  final stationsBox = await openBoxWithRecovery<AppStationModel>(
    'stations',
    cipher: cipher,
  );
  await purgePoisonedFrames(
    stationsBox,
    name: 'stations',
    overreadDetected: () => AppStationModelAdapter.overreadDetected,
  );
  await openBoxWithRecovery<AppSessionRecordModel>(
    'session_records',
    cipher: cipher,
  );
  await openBoxWithRecovery<AppZoneModel>('floor_zones', cipher: cipher);
  await openBoxWithRecovery<AppTableModel>('tables', cipher: cipher);
  await openBoxWithRecovery<AppTableRoundModel>('table_rounds', cipher: cipher);
  final auditBox = await openLazyBoxWithRecovery<String>(
    'audit_log',
    cipher: cipher,
  );
  await openLazyBoxWithRecovery<AppExpenseModel>('expenses', cipher: cipher);
  final auditService = AuditService(box: auditBox);

  print('[PrintServer] Building print server...');
  final printServerManager = PrintServerFactory.create();

  if (Platform.isLinux) {
    // Linux-specific: ensure PrintServer.Linux is built (dev) or present (installed)
    final printServerBuilt = await _ensurePrintServerLinuxBuilt();
    if (printServerBuilt) {
      await printServerManager.start();
    } else {
      print(
        '[PrintServer.Linux] Skipping start — publish failed or executable missing',
      );
    }
  } else {
    final printServerBuilt = await ensurePrintServerBuilt();
    if (printServerBuilt) {
      await printServerManager.start();
    } else {
      print(
        '[PrintServer] Skipping start — publish failed or executable missing',
      );
    }
  }

  final licenseEngine = LicenseEngine();
  unawaited(
    silentLicenseCheck(licenseEngine),
  ); // fire-and-forget, errors logged internally

  runApp(
    App(
      settingsRepository: SettingsRepository(box: settingsBox),
      inventoryRepository: InventoryRepository(box: inventoryBox),
      authRepository: AuthRepositoryImpl(box: authBox),
      shiftsRepository: ShiftsRepositoryImpl(
        box: shiftsBox,
        activeBox: activeShiftsBox,
      ),
      printServerManager: printServerManager,
      licenseEngine: licenseEngine,
      auditService: auditService,
      hiveCipher: cipher,
    ),
  );
}
