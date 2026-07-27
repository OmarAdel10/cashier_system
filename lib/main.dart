import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
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
import 'features/receipts/data/models/receipt_item_adapter.dart';
import 'core/audit/audit_service.dart';
import 'features/settings/data/models/app_settings_model.dart';
import 'features/settings/data/repositories/settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Future<void> ensurePrintServerBuilt() async {
    final buildDir = [
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
      'PrintServer.exe',
    ].join(Platform.pathSeparator);
    final binDir = [
      'PrintServer',
      'bin',
      'Debug',
      'net8.0',
      'PrintServer.exe',
    ].join(Platform.pathSeparator);
    if (File(buildDir).existsSync() || File(binDir).existsSync()) return;

    print('[PrintServer] Building .NET project...');
    final csproj = [
      'PrintServer',
      'PrintServer.csproj',
    ].join(Platform.pathSeparator);
    final result = await Process.run('dotnet', [
      'build',
      csproj,
      '-c',
      'Debug',
    ]);
    if (result.exitCode != 0) {
      print('[PrintServer] Build failed:\n${result.stderr}');
    } else {
      print('[PrintServer] Build succeeded');
    }
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

  final settingsBox = await Hive.openBox<AppSettingsModel>(
    'settings',
    encryptionCipher: cipher,
  );
  final inventoryBox = await Hive.openBox<AppProductModel>(
    'inventory',
    encryptionCipher: cipher,
  );
  final authBox = await Hive.openBox<AppUserModel>(
    'auth_users',
    encryptionCipher: cipher,
  );
  final shiftsBox = await Hive.openBox<AppShiftModel>(
    'shifts',
    encryptionCipher: cipher,
  );
  final activeShiftsBox = await Hive.openBox<String>(
    'active_shifts',
    encryptionCipher: cipher,
  );
  final auditBox = await Hive.openBox<String>(
    'audit_log',
    encryptionCipher: cipher,
  );
  final auditService = AuditService(box: auditBox);

  final hydratedDir = await getApplicationDocumentsDirectory();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(hydratedDir.path),
  );

  await ensurePrintServerBuilt();

  final printServerManager = PrintServerManager();
  await printServerManager.start();

  final licenseEngine = LicenseEngine();
  unawaited(silentLicenseCheck(licenseEngine));

  // Open large boxes last to minimize peak memory during startup
  await Hive.openBox<AppReceiptModel>('receipts', encryptionCipher: cipher);
  await Hive.openBox<AppRefundModel>('refunds', encryptionCipher: cipher);

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
    ),
  );
}
