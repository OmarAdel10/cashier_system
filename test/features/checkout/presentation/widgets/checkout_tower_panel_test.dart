import 'package:cashier_system/core/widgets/section_card.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_tower_panel.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../settings/helpers/fake_settings_repository.dart';

Future<void> _pumpPanel(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final settingsBloc = SettingsBloc(
    repository: FakeSettingsRepository(
      const AppSettingsEntity(languageCode: 'en'),
    ),
  );
  addTearDown(settingsBloc.close);
  settingsBloc.add(LoadSettings());

  final checkoutBloc = CheckoutBloc();
  addTearDown(checkoutBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settingsBloc),
            BlocProvider.value(value: checkoutBloc),
          ],
          child: const CheckoutTowerPanel(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders receipt tower and cash drawer sections', (tester) async {
    await _pumpPanel(tester);

    expect(find.byType(SectionCard), findsNWidgets(2));
    expect(find.text('Cash Drawer'), findsOneWidget);
    expect(find.text('Expenses'), findsNothing);
  });
}
