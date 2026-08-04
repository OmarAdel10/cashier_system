import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'core/audit/audit_service.dart';
import 'core/licensing/domain/enums/license_status.dart';
import 'core/licensing/engine/license_engine.dart';
import 'core/licensing/presentation/activation_screen.dart';
import 'core/printing/print_server_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/models/app_user_model.dart';
import 'features/auth/data/models/app_shift_model.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/shifts_repository_impl.dart';
import 'features/auth/domain/repositories/i_auth_repository.dart';
import 'features/auth/domain/repositories/i_shifts_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/bloc/shift_bloc.dart';
import 'features/auth/presentation/bloc/shift_event.dart';
import 'features/onboarding/presentation/views/onboarding_flow.dart';
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
import 'features/settings/presentation/bloc/settings_state.dart';
import 'presentation/app_shell.dart';

class App extends StatefulWidget {
  final ISettingsRepository? settingsRepository;
  final IInventoryRepository? inventoryRepository;
  final IAuthRepository? authRepository;
  final IShiftsRepository? shiftsRepository;
  final PrintServerManager? printServerManager;
  final LicenseEngine? licenseEngine;
  final AuditService? auditService;
  final HiveAesCipher? hiveCipher;

  const App({
    this.settingsRepository,
    this.inventoryRepository,
    this.authRepository,
    this.shiftsRepository,
    this.printServerManager,
    this.licenseEngine,
    this.auditService,
    this.hiveCipher,
    super.key,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _licenseStatusNotifier = ValueNotifier<LicenseStatus>(LicenseStatus.checking);
  AuthStatus? _lastSettledStatus;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final engine = widget.licenseEngine ?? LicenseEngine();
    final status = await engine.verifyLicense();
    if (!mounted) return;
    _licenseStatusNotifier.value = status;
  }

  @override
  void dispose() {
    _licenseStatusNotifier.dispose();
    widget.printServerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _licenseStatusNotifier,
      builder: (context, _) {
        if (_licenseStatusNotifier.value == LicenseStatus.checking) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (_licenseStatusNotifier.value != LicenseStatus.valid) {
          final settingsBox = Hive.box<AppSettingsModel>('settings');
          final langCode = settingsBox.get('settings')?.languageCode ?? 'ar';
          return ActivationScreen(
            onActivated: () {
              _checkLicense();
            },
            langCode: langCode,
          );
        }

        final licenseEngine = widget.licenseEngine;
        final settingsRepo = widget.settingsRepository ??
            SettingsRepository(box: Hive.box<AppSettingsModel>('settings'));

        final authRepo = widget.authRepository ??
            AuthRepositoryImpl(box: Hive.box<AppUserModel>('auth_users')) as IAuthRepository;

        final shiftsRepo = widget.shiftsRepository ??
            ShiftsRepositoryImpl(box: Hive.box<AppShiftModel>('shifts'), activeBox: Hive.box<String>('active_shifts')) as IShiftsRepository;

        return RepositoryProvider<AuditService>.value(
          value: widget.auditService ?? AuditService(box: Hive.lazyBox<String>('audit_log')),
          child: MultiBlocProvider(
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
                    repository: widget.inventoryRepository ??
                        InventoryRepository(
                          box: Hive.box<AppProductModel>('inventory'),
                        ),
                  );
                  bloc.add(const LoadInventory());
                  return bloc;
                },
              ),
              BlocProvider(
                create: (_) => ShiftBloc(repository: shiftsRepo, licenseEngine: licenseEngine),
              ),
              BlocProvider(
                create: (contextCreate) {
                  final bloc = CheckoutBloc(
                    licenseEngine: licenseEngine,
                    generateOrderNumber: () {
                      final shiftBloc = contextCreate.read<ShiftBloc>();
                      final shift = shiftBloc.state.shift;
                      if (shift == null) return 'ORD-00001';
                      final counter = shift.orderCount;
                      shiftBloc.add(IncrementShiftOrderCount(shift.id));
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
                create: (context) => AuthBloc(
                  repository: authRepo,
                  auditService: context.read<AuditService>(),
                )..add(const CheckAuth()),
              ),
            ],
            child: RepositoryProvider<IAuthRepository>.value(
              value: authRepo,
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
                      if (authState.status != AuthStatus.initial &&
                          authState.status != AuthStatus.loading) {
                        _lastSettledStatus = authState.status;
                      }
                      final status = authState.status == AuthStatus.loading &&
                              _lastSettledStatus != null
                          ? _lastSettledStatus!
                          : authState.status;
                      switch (status) {
                        case AuthStatus.initial:
                        case AuthStatus.loading:
                          return const Scaffold(
                            body: LinearProgressIndicator(minHeight: 2),
                          );
                        case AuthStatus.setupRequired:
                          return const OnboardingFlow();
                        case AuthStatus.authenticated:
                          return AppShell(
                            user: authState.user!,
                            hiveCipher: widget.hiveCipher,
                          );
                        case AuthStatus.passwordChangeRequired:
                        case AuthStatus.unauthenticated:
                          return const LoginScreen();
                      }
                    },
                  ),
                );
              },
            ),
            ),
          ),
        );
      },
    );
  }
}
