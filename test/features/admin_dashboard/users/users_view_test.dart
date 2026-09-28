// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/users/users_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/users/users_view.dart';

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
            {
              'username': 'boss',
              'role': 'admin',
              'is_active': 1,
              'display_name': 'The Boss',
            },
            {
              'username': 'cash1',
              'role': 'cashier',
              'is_active': 1,
              'display_name': null,
            },
          ],
        },
      }),
    );
  });

  Widget view({required bool isOwner}) {
    // Scaffold provides the Material ancestor the ListTiles need
    // (production gets it from AdminShell's Scaffold).
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<UsersBloc>(
          create: (_) =>
              UsersBloc(api: api, tokenProvider: () async => 'tok')
                ..add(const UsersRequested()),
          child: UsersView(isOwner: isOwner),
        ),
      ),
    );
  }

  testWidgets('UsersView renders the list rows (role labels + names)', (
    tester,
  ) async {
    await tester.pumpWidget(view(isOwner: true));
    await tester.pumpAndSettle();
    expect(find.text('المستخدمون (2)'), findsOneWidget);
    expect(find.text('The Boss'), findsOneWidget); // display_name preferred
    expect(find.text('cash1'), findsOneWidget); // username fallback
    expect(find.text('إضافة مستخدم'), findsOneWidget);
  });

  testWidgets('the owner dialog offers both roles', (tester) async {
    await tester.pumpWidget(view(isOwner: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة مستخدم'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة مستخدم'), findsWidgets); // dialog title + button
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
  });

  testWidgets('a session admin dialog is locked to cashier', (tester) async {
    await tester.pumpWidget(view(isOwner: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة مستخدم'));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('الدور: كاشير'), findsOneWidget);
  });
}
