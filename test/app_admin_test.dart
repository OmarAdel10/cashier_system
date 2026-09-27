// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/app_admin.dart';

void main() {
  testWidgets('AdminApp boots and renders the admin shell', (tester) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.text('Daftari Admin'), findsOneWidget);
  });

  testWidgets('AdminApp carries the ar/en localization delegates', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminApp());
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.supportedLocales.length, 2);
    expect(material.supportedLocales, contains(const Locale('ar')));
    expect(material.supportedLocales, contains(const Locale('en')));
    expect(
      material.localizationsDelegates!.contains(
        GlobalMaterialLocalizations.delegate,
      ),
      isTrue,
    );
    expect(
      material.localizationsDelegates!.contains(
        GlobalWidgetsLocalizations.delegate,
      ),
      isTrue,
    );
    expect(
      material.localizationsDelegates!.contains(
        GlobalCupertinoLocalizations.delegate,
      ),
      isTrue,
    );
  });

  testWidgets('AdminApp pins the title, light theme, and no debug banner', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminApp());
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.title, 'Daftari Admin');
    expect(material.debugShowCheckedModeBanner, isFalse);
    expect(material.theme?.brightness, Brightness.light);
  });
}
