import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/app.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_flow.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../../helpers/fake_license_engine.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../auth/helpers/fake_shifts_repository.dart';
import '../../../inventory/helpers/fake_inventory_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _FailingSetupAuthRepository extends FakeAuthRepository {
  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async =>
      Left(DatabaseFailure('DB error'));
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        switch (authState.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(body: LinearProgressIndicator(minHeight: 2));
          case AuthStatus.setupRequired:
            return const OnboardingFlow();
          case AuthStatus.authenticated:
            return const Scaffold(body: Text('APP_SHELL'));
          case AuthStatus.passwordChangeRequired:
          case AuthStatus.unauthenticated:
            return const Scaffold(body: Text('LOGIN'));
        }
      },
    );
  }
}

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> close() async {}
}

void main() {
  late LazyBox<String> auditBox;

  setUpAll(() {
    Hive.init('test/_hive_test_onboarding_gate');
  });

  setUp(() async {
    HydratedBloc.storage = _MockStorage();
    auditBox = await Hive.openLazyBox<String>('audit_log');
  });

  tearDown(() async {
    await auditBox.close();
    await Hive.deleteBoxFromDisk('audit_log');
  });

  Future<void> reachSetupViaBloc(WidgetTester tester) async {
    await tester.tap(find.text('Cafe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('setupRequired shows OnboardingFlow; completing setup exits it',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = FakeAuthRepository()..setSetupCompleted(false);
    final settingsBloc = SettingsBloc(repository: FakeSettingsRepository())
      ..add(const LoadSettings())
      ..add(const LanguageToggled('en'));

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(repository: repository)
              ..add(const CheckAuth()),
          ),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: const _Gate(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await reachSetupViaBloc(tester);
    await tester.enterText(find.byType(TextField).first, 'adminpass123');
    await tester.enterText(find.byType(TextField).at(1), 'adminpass123');
    await tester.tap(find.text('Complete Setup'));
    await tester.pumpAndSettle();

    expect(find.text('APP_SHELL'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('failing setup keeps Admin Setup mounted with DB error banner',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    auditBox = await Hive.openLazyBox<String>('audit_log');
    final repository = _FailingSetupAuthRepository()..setSetupCompleted(false);

    await tester.pumpWidget(App(
      authRepository: repository,
      settingsRepository: FakeSettingsRepository(
        const AppSettingsEntity(languageCode: 'en'),
      ),
      inventoryRepository: FakeInventoryRepository(),
      shiftsRepository: FakeShiftsRepository(),
      licenseEngine: FakeLicenseEngine(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await reachSetupViaBloc(tester);
    await tester.enterText(find.byType(TextField).first, 'adminpass123');
    await tester.enterText(find.byType(TextField).at(1), 'adminpass123');
    await tester.tap(find.text('Complete Setup'));
    await tester.pumpAndSettle();

    expect(find.text('Set Admin Password'), findsOneWidget);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('DB error'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });
}
