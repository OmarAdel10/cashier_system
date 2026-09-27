// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/app_admin.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/login/admin_auth_service.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockAdminAuthService extends Mock implements AdminAuthService {}

void main() {
  late MockFirebaseAuthService firebase;
  late MockAdminAuthService admin;

  setUp(() {
    firebase = MockFirebaseAuthService();
    admin = MockAdminAuthService();
    when(() => firebase.isSignInWithEmailLink(any())).thenReturn(false);
    when(() => admin.storedToken()).thenAnswer((_) async => null);
    when(() => admin.storedTenantId()).thenAnswer((_) async => null);
  });

  testWidgets('AdminApp boots into the two-stage login gate', (tester) async {
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    // The injected-bloc path bypasses AdminApp's create-side dispatch —
    // the test drives the event itself.
    bloc.add(const CheckSessionRequested());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (bloc.state is FirebaseStage) break;
    }
    debugPrint('STATE: ${bloc.state}');
    expect(find.text('دفتري — لوحة التحكم'), findsOneWidget);
    expect(find.textContaining('Sign in with Google'), findsOneWidget);
    // No bloc.close() here: closing inside a widget test can deadlock the
    // test isolate's stream sink (flutter_tools FlutterPlatform) — the
    // framework disposes the tree.
  });

  testWidgets('AdminApp carries the ar/en localization delegates', (
    tester,
  ) async {
    final bloc = AdminAuthBloc(firebase: firebase, admin: admin);
    await tester.pumpWidget(AdminApp(bloc: bloc));
    await tester.pumpAndSettle();
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.supportedLocales.length, 2);
    expect(
      material.localizationsDelegates!.contains(
        GlobalMaterialLocalizations.delegate,
      ),
      isTrue,
    );
  });
}
