import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/widgets/add_user_dialog.dart';
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

Widget createTestApp({
  required AuthBloc authBloc,
  required SettingsBloc settingsBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
    ],
    child: const MaterialApp(home: Scaffold(body: AddUserDialog())),
  );
}

void main() {
  group('AddUserDialog', () {
    testWidgets('shows username, password fields and role selector', (tester) async {
      HydratedBloc.storage = _MockStorage();
      final authBloc = AuthBloc(repository: FakeAuthRepository());
      final settingsRepo = FakeSettingsRepository(AppSettingsEntity(languageCode: 'en'));
      final settingsBloc = SettingsBloc(repository: settingsRepo);
      settingsBloc.add(const LoadSettings());
      addTearDown(authBloc.close);
      addTearDown(settingsBloc.close);
      await tester.pumpWidget(createTestApp(authBloc: authBloc, settingsBloc: settingsBloc));
      await tester.pumpAndSettle();
      expect(find.text('Add User'), findsWidgets);
      expect(find.text('Cashier'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
