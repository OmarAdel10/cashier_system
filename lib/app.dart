import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/models/app_user_model.dart';
import 'features/auth/data/models/app_shift_model.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/shifts_repository_impl.dart';
import 'features/auth/domain/repositories/i_auth_repository.dart';
import 'features/auth/domain/repositories/i_shifts_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/bloc/shift_bloc.dart';
import 'features/auth/presentation/views/login_screen.dart';
import 'features/checkout/presentation/bloc/checkout_bloc.dart';
import 'features/checkout/presentation/bloc/checkout_event.dart';
import 'features/inventory/data/models/app_product_model.dart';
import 'features/inventory/data/repositories/inventory_repository.dart';
import 'features/inventory/domain/repositories/i_inventory_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/settings/data/models/app_settings_model.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/data/services/localization_service.dart';
import 'features/settings/domain/repositories/i_settings_repository.dart';
import 'features/inventory/presentation/bloc/inventory_event.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/settings/presentation/bloc/settings_state.dart';
import 'presentation/app_shell.dart';

String _todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class App extends StatelessWidget {
  final ISettingsRepository? settingsRepository;
  final IInventoryRepository? inventoryRepository;
  final IAuthRepository? authRepository;
  final IShiftsRepository? shiftsRepository;

  const App({
    this.settingsRepository,
    this.inventoryRepository,
    this.authRepository,
    this.shiftsRepository,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settingsRepo = settingsRepository ??
        SettingsRepository(box: Hive.box<AppSettingsModel>('settings'));

    final authRepo = authRepository ??
        AuthRepositoryImpl(box: Hive.box<AppUserModel>('auth_users')) as IAuthRepository;

    final shiftsRepo = shiftsRepository ??
        ShiftsRepositoryImpl(box: Hive.box<AppShiftModel>('shifts'), activeBox: Hive.box<String>('active_shifts')) as IShiftsRepository;

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
          create: (_) {
            final bloc = InventoryBloc(
              repository: inventoryRepository ??
                  InventoryRepository(
                    box: Hive.box<AppProductModel>('inventory'),
                  ),
            );
            bloc.add(const LoadInventory());
            return bloc;
          },
        ),
        BlocProvider(
          create: (contextCreate) {
            final bloc = CheckoutBloc(
              generateOrderNumber: () {
                final settingsBloc = contextCreate.read<SettingsBloc>();
                final state = settingsBloc.state;
                final today = _todayString();
                final counter = state.settings.lastOrderDate == today
                    ? state.settings.orderCounter + 1
                    : 1;
                settingsBloc.add(UpdateOrderCounter(counter, today));
                return 'ORD-${counter.toString().padLeft(5, '0')}';
              },
            );
            final settingsState = contextCreate.read<SettingsBloc>().state;
            bloc.add(SetTaxPercent(
              settingsState.settings.taxEnabled
                  ? settingsState.settings.taxPercent
                  : 0,
            ));
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) => AuthBloc(repository: authRepo)..add(const CheckAuth()),
        ),
        BlocProvider(
          create: (_) => ShiftBloc(repository: shiftsRepo),
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
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                switch (authState.status) {
                  case AuthStatus.initial:
                  case AuthStatus.loading:
                    return const Scaffold(
                      body: LinearProgressIndicator(minHeight: 2),
                    );
                  case AuthStatus.authenticated:
                    return AppShell(user: authState.user!);
                  case AuthStatus.unauthenticated:
                    return const LoginScreen();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
