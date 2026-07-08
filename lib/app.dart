import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'features/settings/presentation/views/settings_workspace.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsBloc(),
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Al-Maktaba - POS System',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorSchemeSeed: const Color(0xFF007ACC),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              cardTheme: const CardThemeData(
                color: Color(0xFFFFFFFF),
                surfaceTintColor: Color(0xFFFFFFFF),
              ),
              dividerColor: const Color(0xFFE2E8F0),
              fontFamily: 'Cairo',
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: const Color(0xFF007ACC),
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              cardTheme: const CardThemeData(
                color: Color(0xFF1E293B),
                surfaceTintColor: Color(0xFF1E293B),
              ),
              dividerColor: const Color(0xFF334155),
              fontFamily: 'Cairo',
            ),
            themeMode: state.settings.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: Locale(state.settings.languageCode),
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const SettingsWorkspace(),
          );
        },
      ),
    );
  }
}
