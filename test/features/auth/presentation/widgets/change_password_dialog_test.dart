import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/widgets/change_password_dialog.dart';
import '../../helpers/fake_auth_repository.dart';

Widget createTestApp(AuthBloc bloc) {
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: const MaterialApp(
      home: Scaffold(body: ChangePasswordDialog(username: 'admin')),
    ),
  );
}

void main() {
  group('ChangePasswordDialog', () {
    testWidgets('shows three password fields and title', (tester) async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      addTearDown(bloc.close);
      await tester.pumpWidget(createTestApp(bloc));
      await tester.pumpAndSettle();
      expect(find.text('Change Password'), findsWidgets);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password (min 8)'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });
  });
}
