import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_tower_panel.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../../features/settings/helpers/fake_settings_repository.dart';

Widget buildTower({required String businessType, AppSettingsEntity? settings}) {
  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      settings ??
          AppSettingsEntity(languageCode: 'en', businessType: businessType),
    ),
  );
  settingsBloc.add(const LoadSettings());
  final checkoutBloc = CheckoutBloc();
  addTearDown(() {
    settingsBloc.close();
    checkoutBloc.close();
  });
  return MaterialApp(
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
        ],
        child: const CheckoutTowerPanel(),
      ),
    ),
  );
}

void main() {
  Future<void> pumpWithSize(
    WidgetTester tester,
    String businessType, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTower(businessType: businessType));
    await tester.pumpAndSettle();
  }

  testWidgets('playstation tower shows totals and drawer without receipt', (
    tester,
  ) async {
    await pumpWithSize(tester, 'playstation');

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Cash Drawer'), findsOneWidget);
    expect(find.text('Receipt'), findsNothing);
    expect(find.text('Cart & receipt will appear here'), findsNothing);
  });

  testWidgets('cafe tower keeps receipt preview', (tester) async {
    await pumpWithSize(tester, 'cafe');

    expect(find.text('Receipt'), findsWidgets);
    expect(find.text('Cash Drawer'), findsOneWidget);
  });

  testWidgets('restaurant tower keeps receipt preview', (tester) async {
    await pumpWithSize(tester, 'restaurant');

    expect(find.text('Receipt'), findsWidgets);
    expect(find.text('Cash Drawer'), findsOneWidget);
  });

  testWidgets('retail tower keeps receipt preview', (tester) async {
    await pumpWithSize(tester, 'retail');

    expect(find.text('Receipt'), findsWidgets);
    expect(find.text('Cash Drawer'), findsOneWidget);
  });
}
