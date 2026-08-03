import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_flow.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

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
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

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
    await tester.enterText(find.byType(TextField).first, 'adminpass123');
    await tester.enterText(find.byType(TextField).at(1), 'adminpass123');
    await tester.tap(find.text('Complete Setup'));
    await tester.pumpAndSettle();

    expect(find.text('APP_SHELL'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });
}
