import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'features/auth/data/models/app_user_model.dart';
import 'features/auth/data/models/app_shift_model.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/shifts_repository_impl.dart';
import 'features/inventory/data/models/app_product_model.dart';
import 'features/inventory/data/repositories/inventory_repository.dart';
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
  final settingsBox = await Hive.openBox<AppSettingsModel>('settings');
  final inventoryBox = await Hive.openBox<AppProductModel>('inventory');
  final authBox = await Hive.openBox<AppUserModel>('auth_users');
  final shiftsBox = await Hive.openBox<AppShiftModel>('shifts');

  runApp(App(
    settingsRepository: SettingsRepository(box: settingsBox),
    inventoryRepository: InventoryRepository(box: inventoryBox),
    authRepository: AuthRepositoryImpl(box: authBox),
    shiftsRepository: ShiftsRepositoryImpl(box: shiftsBox),
  ));
}
