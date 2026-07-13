import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/auth/presentation/views/login_screen.dart';
import '../../helpers/fake_auth_repository.dart';

class MockAuthBloc extends AuthBloc {
  MockAuthBloc(AuthState initialState) : super(repository: FakeAuthRepository()) {
    emit(initialState);
  }
}

Widget createTestApp(AuthState state) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>(
      create: (_) => MockAuthBloc(state),
      child: const LoginScreen(),
    ),
  );
}

void main() {
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
