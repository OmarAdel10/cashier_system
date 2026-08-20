import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_flow.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_preferences_screen.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_welcome_screen.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

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

class MockAuthBloc extends AuthBloc {
  MockAuthBloc(AuthState initialState)
    : super(repository: FakeAuthRepository()) {
    emit(initialState);
  }
}

Widget createFlowApp(AuthState state) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => MockAuthBloc(state)),
        BlocProvider<SettingsBloc>(
          create: (_) {
            final bloc = SettingsBloc(repository: FakeSettingsRepository());
            bloc.add(const LoadSettings());
            bloc.add(const LanguageToggled('en'));
            return bloc;
          },
        ),
      ],
      child: const OnboardingFlow(),
    ),
  );
}

const _businessTypeTitle = 'What is your business type?';

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  Future<void> pumpDesktop(WidgetTester tester, AuthState state) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createFlowApp(state));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    final next = find.text('Next');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    final back = find.text('Back');
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
  }

  Future<void> tapSkip(WidgetTester tester) async {
    final skip = find.text('Skip');
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }

  Future<void> selectCafeAndNext(WidgetTester tester) async {
    await tester.tap(find.text('Cafe'));
    await tester.pumpAndSettle();
    await tapNext(tester);
  }

  Future<void> advanceToAdminSetup(WidgetTester tester) async {
    await selectCafeAndNext(tester);
    for (var i = 0; i < 5; i++) {
      await tapNext(tester);
    }
  }

  group('OnboardingFlow', () {
    const setupState = AuthState(status: AuthStatus.setupRequired);

    testWidgets('starts on welcome screen', (tester) async {
      await pumpDesktop(tester, setupState);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Next advances welcome -> features -> business type', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);

      await tapNext(tester);
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('Skip from welcome lands on business type step', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('Skip from features lands on business type step', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tapSkip(tester);
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('business type screen shows all options with Next disabled', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);

      for (final name in [
        'Retail Store',
        'Supermarket',
        'Cafe',
        'Restaurant',
        'PlayStation',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(nextButton.onPressed, isNull);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('selecting a type enables Next and persists to settings', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);

      await tester.tap(find.text('Cafe'));
      await tester.pumpAndSettle();

      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next'),
      );
      expect(nextButton.onPressed, isNotNull);

      final context = tester.element(find.text(_businessTypeTitle));
      final settings = BlocProvider.of<SettingsBloc>(context).state.settings;
      expect(settings.businessType, 'cafe');
    });

    testWidgets('Back from business type returns to features', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);

      await tapBack(tester);
      expect(find.text('Everything you need in one place'), findsOneWidget);
    });

    testWidgets('business type Next advances through new setup steps', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);

      expect(find.text('Store Info'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Store Logo'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Export folder'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Printing setup'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Preferences'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('store info fields persist to settings', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);

      expect(find.text('Store Info'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Store Name'),
        'My Store',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Store Address'),
        'Cairo',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone Number'),
        '012345',
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Store Info'));
      final settings = BlocProvider.of<SettingsBloc>(context).state.settings;
      expect(settings.storeName, 'My Store');
      expect(settings.storeAddress, 'Cairo');
      expect(settings.storePhoneNumber, '012345');
    });

    testWidgets('back from store info returns to business type', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);
      expect(find.text('Store Info'), findsOneWidget);

      await tapBack(tester);
      expect(find.text(_businessTypeTitle), findsOneWidget);
    });

    testWidgets('skip from store info jumps to admin setup', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);
      expect(find.text('Store Info'), findsOneWidget);

      await tapSkip(tester);
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('welcome language selection persists to settings', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OnboardingWelcomeScreen));
      final settings = BlocProvider.of<SettingsBloc>(context).state.settings;
      expect(settings.languageCode, 'ar');
    });

    testWidgets('preferences tax toggle persists to settings', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);
      for (var i = 0; i < 4; i++) {
        await tapNext(tester);
      }
      expect(find.text('Preferences'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OnboardingPreferencesScreen));
      final settings = BlocProvider.of<SettingsBloc>(context).state.settings;
      expect(settings.taxEnabled, isTrue);
    });

    testWidgets('skip from preferences jumps to admin setup', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await selectCafeAndNext(tester);
      for (var i = 0; i < 4; i++) {
        await tapNext(tester);
      }
      expect(find.text('Preferences'), findsOneWidget);

      await tapSkip(tester);
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('setup screen has no Skip and no Next', (tester) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await advanceToAdminSetup(tester);
      expect(find.text('Set Admin Password'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Back from setup returns to business type then features', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tapSkip(tester);
      await advanceToAdminSetup(tester);

      await tapBack(tester);
      expect(find.text('Preferences'), findsOneWidget);

      final context = tester.element(find.text('Preferences'));
      final bloc = BlocProvider.of<OnboardingBloc>(context);
      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Printing setup'), findsOneWidget);
      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Export folder'), findsOneWidget);
      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Store Logo'), findsOneWidget);
      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Store Info'), findsOneWidget);
      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text(_businessTypeTitle), findsOneWidget);

      bloc.add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);
    });
  });
}
