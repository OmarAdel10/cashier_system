import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_tower_panel.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../settings/helpers/fake_settings_repository.dart';

Future<CheckoutBloc> _pumpPanel(WidgetTester tester) async {
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
  return checkoutBloc;
}

Finder _paymentButton(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;
}

void main() {
  const labels = ['Cash', 'InstaPay', 'Vodafone Cash', 'Visa'];

  testWidgets('payment type buttons match cash button size', (tester) async {
    await _pumpPanel(tester);

    final cashSize = tester.getSize(_paymentButton('EGP 5.00'));
    for (final label in labels) {
      expect(tester.getSize(_paymentButton(label)).width, cashSize.width);
      expect(tester.getSize(_paymentButton(label)).height, cashSize.height);
      expect(tester.getSize(_paymentButton(label)).height, 56);
    }
  });

  testWidgets('payment type buttons are evenly spaced', (tester) async {
    await _pumpPanel(tester);

    final gaps = <double>[];
    for (var i = 1; i < labels.length; i++) {
      final prevRight =
          tester.getTopLeft(_paymentButton(labels[i - 1])).dx +
          tester.getSize(_paymentButton(labels[i - 1])).width;
      final currLeft = tester.getTopLeft(_paymentButton(labels[i])).dx;
      gaps.add(currLeft - prevRight);
    }
    expect(gaps.toSet().length, 1);
  });

  testWidgets('tapping a payment type button selects it', (tester) async {
    final checkoutBloc = await _pumpPanel(tester);

    await tester.tap(_paymentButton('Visa'));
    await tester.pump();

    expect(checkoutBloc.state.paymentType, 'visa');

    final material = tester.widget<Material>(
      find
          .ancestor(of: find.text('Visa'), matching: find.byType(Material))
          .first,
    );
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, isNotNull);
    expect(shape.side.width, 2);
  });

  testWidgets('unselected payment type button has plain border', (
    tester,
  ) async {
    await _pumpPanel(tester);

    for (final label in labels.where((l) => l != 'Cash')) {
      expect(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
        findsOneWidget,
      );
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape as RoundedRectangleBorder;
      expect(shape.side.width, isNot(2));
    }
  });
}
