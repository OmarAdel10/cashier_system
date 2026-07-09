import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/inventory/data/models/app_product_model.dart';
import 'features/inventory/data/repositories/inventory_repository.dart';
import 'features/inventory/domain/repositories/i_inventory_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/settings/data/models/app_settings_model.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/data/services/localization_service.dart';
import 'features/settings/domain/repositories/i_settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'presentation/app_shell.dart';
import 'package:hive/hive.dart';

class App extends StatelessWidget {
  final ISettingsRepository? settingsRepository;
  final IInventoryRepository? inventoryRepository;

  const App({
    this.settingsRepository,
    this.inventoryRepository,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settingsRepo = settingsRepository ??
        SettingsRepository(box: Hive.box<AppSettingsModel>('settings'));

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = SettingsBloc(repository: settingsRepo);
            bloc.add(const LoadSettings());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) => InventoryBloc(
            repository: inventoryRepository ??
                InventoryRepository(
                  box: Hive.box<AppProductModel>('inventory'),
                ),
          ),
        ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final langCode = state.settings.languageCode;
          final t = LocalizationService();

          return MaterialApp(
            title: t.translate('appTitle', languageCode: langCode),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: state.settings.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: Locale(langCode),
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
