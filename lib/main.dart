import 'dart:async';
import 'dart:convert';
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
import 'features/settings/data/models/app_settings_model.dart';
import 'features/settings/data/repositories/settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(dir.path),
  );

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
    storedKey = base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));
    await storage.write(key: 'hive_encryption_key', value: storedKey);
  }
  final encryptionKey = base64.decode(storedKey);

  final settingsBox = await Hive.openBox<AppSettingsModel>('settings', encryptionKey: encryptionKey);
  final inventoryBox = await Hive.openBox<AppProductModel>('inventory', encryptionKey: encryptionKey);
  final authBox = await Hive.openBox<AppUserModel>('auth_users', encryptionKey: encryptionKey);
  final shiftsBox = await Hive.openBox<AppShiftModel>('shifts', encryptionKey: encryptionKey);
  final activeShiftsBox = await Hive.openBox<String>('active_shifts', encryptionKey: encryptionKey);
  await Hive.openBox<AppReceiptModel>('receipts', encryptionKey: encryptionKey);
  await Hive.openBox<AppRefundModel>('refunds', encryptionKey: encryptionKey);

  final printServerManager = PrintServerManager();
  await printServerManager.start();

  unawaited(_silentLicenseCheck());

  runApp(App(
    settingsRepository: SettingsRepository(box: settingsBox),
    inventoryRepository: InventoryRepository(box: inventoryBox),
    authRepository: AuthRepositoryImpl(box: authBox),
    shiftsRepository: ShiftsRepositoryImpl(box: shiftsBox, activeBox: activeShiftsBox),
    printServerManager: printServerManager,
    licenseEngine: LicenseEngine(),
  ));
}

Future<void> _silentLicenseCheck() async {
  try {
    final engine = LicenseEngine();
    final status = await engine.verifyLicense();
    if (status == LicenseStatus.tampered) {
      debugPrint('[Licensing] WARNING: License tampered or HWID mismatch detected.');
    }
  } catch (_) {}
}
