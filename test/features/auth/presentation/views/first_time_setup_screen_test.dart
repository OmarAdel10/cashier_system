import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/auth/presentation/views/first_time_setup_screen.dart';
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
      child: const FirstTimeSetupScreen(),
    ),
  );
}

void main() {
  group('FirstTimeSetupScreen', () {
    testWidgets('renders setup form with title and fields', (tester) async {
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
