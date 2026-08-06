import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/time_billing_dialog.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

void main() {
  Future<AddTimedItem?>? result;

  Widget buildHost(ProductEntity product, int minCost) {
    return MaterialApp(
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>(
            create: (_) {
              final bloc = SettingsBloc(
                repository: FakeSettingsRepository(
                  const AppSettingsEntity(languageCode: 'en'),
                ),
              );
              bloc.add(const LoadSettings());
              return bloc;
            },
          ),
        ],
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () {
                result = showTimeBillingDialog(
                  context,
                  product: product,
                  minimumGameCostPiastres: minCost,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    result = null;
  });

  Future<void> openDialog(
    WidgetTester tester, {
    ProductEntity? overrideProduct,
    int overrideMinCost = 0,
  }) async {
    await tester.pumpWidget(
      buildHost(
        overrideProduct ??
            const ProductEntity(barcode: 'ps1', name: 'PS5', price: 15),
        overrideMinCost,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to 4 quarters and shows product name + total', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Quarter hours: 4'), findsOneWidget);
    expect(find.text('PS5'), findsOneWidget);
    expect(find.text('EGP 15.00'), findsOneWidget);
  });

  testWidgets('minus clamps quarters to a minimum of 1', (tester) async {
    await openDialog(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(PhosphorIcons.minus));
      await tester.pump();
    }

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Quarter hours: 1'), findsOneWidget);
  });

  testWidgets('plus increments quarters', (tester) async {
    await openDialog(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(PhosphorIcons.plus));
      await tester.pump();
    }

    expect(find.text('7'), findsOneWidget);
    expect(find.text('Quarter hours: 7'), findsOneWidget);
  });

  testWidgets('confirm returns event with quarters as quantity', (
    tester,
  ) async {
    await openDialog(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(PhosphorIcons.plus));
      await tester.pump();
    }

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final event = await result!;
    expect(event, isA<AddTimedItem>());
    expect(event!.quantity, 7);
    expect(event.barcode, 'ps1');
  });

  testWidgets('applies minimum game cost bump for a single quarter', (
    tester,
  ) async {
    await openDialog(
      tester,
      overrideProduct: const ProductEntity(
        barcode: 'ps1',
        name: 'PS5',
        price: 10,
      ),
      overrideMinCost: 500,
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(PhosphorIcons.minus));
      await tester.pump();
    }

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final event = await result!;
    expect(event!.quantity, 1);
    expect(event.unitPricePiastres, 500);
  });

  testWidgets('Cancel returns null', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(await result!, isNull);
  });
}
