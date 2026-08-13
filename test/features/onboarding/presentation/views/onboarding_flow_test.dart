import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_flow.dart';
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

  Future<void> selectCafeAndNext(WidgetTester tester) async {
    await tester.tap(find.text('Cafe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
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

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('Skip from welcome lands on business type step', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('Skip from features lands on business type step', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text(_businessTypeTitle), findsOneWidget);
      expect(find.text('Set Admin Password'), findsNothing);
    });

    testWidgets('business type screen shows all options with Next disabled', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

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
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

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
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);
    });

    testWidgets('setup screen has no Skip and no Next', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await selectCafeAndNext(tester);
      expect(find.text('Set Admin Password'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Back from setup returns to business type then features', (
      tester,
    ) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await selectCafeAndNext(tester);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text(_businessTypeTitle), findsOneWidget);

      final context = tester.element(find.text(_businessTypeTitle));
      BlocProvider.of<OnboardingBloc>(
        context,
      ).add(const OnboardingPreviousStep());
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);
    });
  });
}
