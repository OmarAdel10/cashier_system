// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/users/add_user_dialog.dart';
import 'package:cashier_system/features/admin_dashboard/users/users_bloc.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    EnvConfig.initializeFromEnv();
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient api;

  setUp(() {
    api = MockApiClient();
    when(
      () => api.get(
        any(),
        idToken: any(named: 'idToken'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => const Right(<String, dynamic>{
        'ok': true,
        'data': {
          'users': [
            {'username': 'boss', 'role': 'admin', 'is_active': 1},
          ],
        },
      }),
    );
    when(
      () => api.post(any(), any(), idToken: any(named: 'idToken')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
  });

  Widget dialog({required bool isOwner}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<UsersBloc>(
          create: (_) => UsersBloc(api: api, tokenProvider: () async => 'tok'),
          child: AddUserDialog(isOwner: isOwner),
        ),
      ),
    );
  }

  testWidgets('a username regex fail shows the error and keeps the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(dialog(isOwner: true));
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المستخدم'),
      'ab',
    ); // 2 chars < 3
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'pw12345678',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();

    expect(
      find.text('اسم المستخدم: 3-30 حرفًا إنجليزيًا/أرقامًا فقط.'),
      findsOneWidget,
    );
    verifyNever(() => api.post(any(), any(), idToken: any(named: 'idToken')));
    expect(find.widgetWithText(FilledButton, 'إضافة'), findsOneWidget);
  });

  testWidgets('a short password shows the error and keeps the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(dialog(isOwner: true));
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المستخدم'),
      'new1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'short',
    ); // 5 chars < 8
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();

    expect(find.text('كلمة المرور: 8 أحرف على الأقل.'), findsOneWidget);
    verifyNever(() => api.post(any(), any(), idToken: any(named: 'idToken')));
    expect(find.widgetWithText(FilledButton, 'إضافة'), findsOneWidget);
  });

  testWidgets('a blank display name maps to null in the created user', (
    tester,
  ) async {
    await tester.pumpWidget(dialog(isOwner: true));
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المستخدم'),
      'new1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'pw12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'الاسم المعروض (اختياري)'),
      '   ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final post = verify(
      () =>
          api.post(captureAny(), captureAny(), idToken: any(named: 'idToken')),
    );
    expect(post.captured[0], '/admin/users');
    expect(
      (post.captured[1] as Map).containsKey('display_name'),
      isFalse,
    ); // blank → null → key omitted
  });

  testWidgets('a valid display name passes through to the created user', (
    tester,
  ) async {
    await tester.pumpWidget(dialog(isOwner: true));
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المستخدم'),
      'new1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'pw12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'الاسم المعروض (اختياري)'),
      'علي',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final post = verify(
      () =>
          api.post(captureAny(), captureAny(), idToken: any(named: 'idToken')),
    );
    expect((post.captured[1] as Map)['display_name'], 'علي');
  });
}
