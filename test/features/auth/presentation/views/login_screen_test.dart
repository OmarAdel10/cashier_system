import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/auth/presentation/views/login_screen.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_auth_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override Future<dynamic> read(String key) async => _store[key];
  @override Future<void> delete(String key) async => _store.remove(key);
  @override Future<void> clear() async => _store.clear();
  @override Future<void> close() async {}
  @override List<String> getKeys() => _store.keys.toList();
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
      ],
      child: const LoginScreen(),
    ),
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  group('LoginScreen', () {
    testWidgets('renders login form with title and fields', (tester) async {
      await tester.pumpWidget(createTestApp(const AuthState()));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows error when auth state has failure', (tester) async {
      const failure = AuthenticationFailure('Invalid credentials', AuthFailureReason.invalidCredentials);
      await tester.pumpWidget(createTestApp(
        AuthState(failure: failure),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
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
