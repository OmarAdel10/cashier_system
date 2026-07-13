import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/auth/presentation/widgets/user_management_section.dart';
import '../../helpers/fake_auth_repository.dart';

class MockUserManagementBloc extends AuthBloc {
  MockUserManagementBloc(AuthState initialState) : super(repository: FakeAuthRepository()) {
    emit(initialState);
  }
}

Widget createTestApp(AuthState state) {
  final currentUser = UserEntity(
    username: 'admin',
    passwordHash: 'hash',
    passwordSalt: 'salt',
    role: UserRole.admin,
    createdAt: DateTime.now(),
  );
  return MaterialApp(
    home: BlocProvider<AuthBloc>(
      create: (_) => MockUserManagementBloc(state),
      child: Scaffold(
        body: UserManagementSection(currentUser: currentUser),
      ),
    ),
  );
}

void main() {
  group('UserManagementSection', () {
    testWidgets('shows title and add user button', (tester) async {
      await tester.pumpWidget(createTestApp(const AuthState(
        status: AuthStatus.authenticated,
        users: [],
      )));
      await tester.pumpAndSettle();
      expect(find.text('User Management'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add User'), findsOneWidget);
    });

    testWidgets('shows loading indicator when status is loading', (tester) async {
      await tester.pumpWidget(createTestApp(const AuthState(
        status: AuthStatus.loading,
      )));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows user list with "You" badge for current user', (tester) async {
      final users = [
        UserEntity(
          username: 'admin',
          passwordHash: 'hash',
          passwordSalt: 'salt',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        ),
        UserEntity(
          username: 'cashier1',
          passwordHash: 'hash',
          passwordSalt: 'salt',
          role: UserRole.cashier,
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(createTestApp(AuthState(
        status: AuthStatus.authenticated,
        users: users,
      )));
      await tester.pumpAndSettle();
      expect(find.text('admin'), findsWidgets);
      expect(find.text('cashier1'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('shows popup menu with change password and delete options', (tester) async {
      final users = [
        UserEntity(
          username: 'cashier1',
          passwordHash: 'hash',
          passwordSalt: 'salt',
          role: UserRole.cashier,
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(createTestApp(AuthState(
        status: AuthStatus.authenticated,
        users: users,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
