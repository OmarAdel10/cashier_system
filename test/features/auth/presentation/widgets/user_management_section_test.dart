import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/auth/presentation/widgets/user_management_section.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../helpers/fake_auth_repository.dart';
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
  HydratedBloc.storage = _MockStorage();
  final settingsRepo = FakeSettingsRepository(AppSettingsEntity(languageCode: 'en'));
  final settingsBloc = SettingsBloc(repository: settingsRepo)..add(const LoadSettings());
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => MockUserManagementBloc(state),
        ),
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
      ],
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
