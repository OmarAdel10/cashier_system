import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/widgets/add_user_dialog.dart';
import '../../helpers/fake_auth_repository.dart';

Widget createTestApp(AuthBloc bloc) {
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: const MaterialApp(home: Scaffold(body: AddUserDialog())),
  );
}

void main() {
  group('AddUserDialog', () {
    testWidgets('shows username, password fields and role selector', (tester) async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      addTearDown(bloc.close);
      await tester.pumpWidget(createTestApp(bloc));
      await tester.pumpAndSettle();
      expect(find.text('Add User'), findsWidgets);
      expect(find.text('Cashier'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
