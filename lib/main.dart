import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
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
  final settingsBox = await Hive.openBox<AppSettingsModel>('settings');

  Bloc.observer = const _SettingsBlocObserver();

  runApp(App(repository: SettingsRepository(box: settingsBox)));
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
