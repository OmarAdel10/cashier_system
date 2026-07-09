import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
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
  final settingsBox = await Hive.openBox<AppSettingsModel>('settings');
  final inventoryBox = await Hive.openBox<AppProductModel>('inventory');

  Bloc.observer = const _SettingsBlocObserver();

  runApp(App(
    settingsRepository: SettingsRepository(box: settingsBox),
    inventoryRepository: InventoryRepository(box: inventoryBox),
  ));
}

class _SettingsBlocObserver extends BlocObserver {
  const _SettingsBlocObserver();

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (bloc is HydratedBloc) {
      // HydratedBloc handles persistence automatically
    }
  }
}
