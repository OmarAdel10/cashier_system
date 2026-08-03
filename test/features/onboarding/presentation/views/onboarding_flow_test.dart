import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
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
        BlocProvider<AuthBloc>(
          create: (_) => MockAuthBloc(state),
        ),
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

  group('OnboardingFlow', () {
    const setupState = AuthState(status: AuthStatus.setupRequired);

    testWidgets('starts on welcome screen', (tester) async {
      await pumpDesktop(tester, setupState);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Next advances welcome -> features -> setup', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('Skip from welcome jumps straight to setup', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('Skip from features jumps to setup', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Set Admin Password'), findsOneWidget);
    });

    testWidgets('setup screen has no Skip and no Next', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Set Admin Password'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Back from setup returns to features', (tester) async {
      await pumpDesktop(tester, setupState);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Everything you need in one place'), findsOneWidget);
    });
  });
}
