import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/licensing/domain/enums/license_status.dart';
import 'core/licensing/engine/license_engine.dart';
import 'core/printing/print_server_manager.dart';
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
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}

Future<LazyBox<T>> openLazyBoxWithRecovery<T>(
  String name, {
  required HiveAesCipher cipher,
}) async {
  try {
    return await Hive.openLazyBox<T>(name, encryptionCipher: cipher);
  } catch (e) {
    debugPrint('[Hive] Lazy box "$name" is corrupt ($e); deleting and reopening.');
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
    return Hive.openLazyBox<T>(name, encryptionCipher: cipher);
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
  final entries = box.toMap();
  for (final entry in entries.entries) {
    await box.put(entry.key, entry.value);
  }
  await box.compact();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ensureKioskFullscreen();

  Future<bool> ensurePrintServerBuilt() async {
    final buildDirExe = [
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
      'PrintServer.exe',
    ].join(Platform.pathSeparator);

    if (File(buildDirExe).existsSync()) return true;

    dev.log('[PrintServer] Publishing .NET project to runner debug folder...');

    final csproj = [
      'PrintServer',
      'PrintServer.csproj',
    ].join(Platform.pathSeparator);

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

  await Hive.initFlutter();
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
  await openBoxWithRecovery<List>(
    'product_categories',
    cipher: cipher,
  );
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
  await openBoxWithRecovery<AppTableRoundModel>(
    'table_rounds',
    cipher: cipher,
  );
  final auditBox = await openLazyBoxWithRecovery<String>(
    'audit_log',
    cipher: cipher,
  );
  await openLazyBoxWithRecovery<AppExpenseModel>('expenses', cipher: cipher);
  final auditService = AuditService(box: auditBox);

  print('[PrintServer] Building print server...');
  final printServerBuilt = await ensurePrintServerBuilt();

  final printServerManager = PrintServerManager();
  if (printServerBuilt) {
    await printServerManager.start();
  } else {
    print(
      '[PrintServer] Skipping start — publish failed or executable missing',
    );
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
