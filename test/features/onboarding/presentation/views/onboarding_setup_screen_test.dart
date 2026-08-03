import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_setup_screen.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override Future<dynamic> read(String key) async => _store[key];
  @override Future<void> delete(String key) async => _store.remove(key);
  @override Future<void> clear() async => _store.clear();
  @override Future<void> close() async {}
  List<String> getKeys() => _store.keys.toList();
}

class MockAuthBloc extends AuthBloc {
  MockAuthBloc(AuthState initialState) : super(repository: FakeAuthRepository()) {
    emit(initialState);
  }
}

Widget createTestApp(AuthState state) {
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
        BlocProvider<OnboardingBloc>(
          create: (_) => OnboardingBloc(),
        ),
      ],
      child: const OnboardingSetupScreen(),
    ),
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  group('OnboardingSetupScreen', () {
    testWidgets('renders setup form with title and fields', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(createTestApp(
        const AuthState(status: AuthStatus.setupRequired),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Set Admin Password'), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('shows error when auth state has failure', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const failure = AuthenticationFailure('DB error', AuthFailureReason.weakPassword);
      await tester.pumpWidget(createTestApp(
        AuthState(status: AuthStatus.setupRequired, failure: failure),
      ));
      await tester.pumpAndSettle();
      expect(find.text('DB error'), findsOneWidget);
    });

    testWidgets('shows loading indicator when status is loading', (tester) async {
      await tester.pumpWidget(createTestApp(
        const AuthState(status: AuthStatus.loading),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });
}
