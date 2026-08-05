import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/views/product_form_dialog.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../helpers/fake_inventory_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}

const _purchasePriceLabel = 'سعر الشراء';
const _purchasePriceWarning =
    'سعر الشراء أعلى من سعر البيع — هل تريد المتابعة؟';
const _purchasePriceWarningProceed = 'متابعة';
const _addButton = 'إضافة';
const _cancelButton = 'إلغاء';
const _newProductTitle = 'منتج جديد';

void main() {
  late InventoryBloc bloc;
  late List<ProductEntity?> results;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = InventoryBloc(repository: FakeInventoryRepository());
    results = [];
  });

  tearDown(() {
    bloc.close();
  });

  Widget buildTestWidget({ProductEntity? product}) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<InventoryBloc>.value(value: bloc),
          BlocProvider<SettingsBloc>(
            create: (_) {
              final sBloc = SettingsBloc(repository: FakeSettingsRepository());
              sBloc.add(const LoadSettings());
              return sBloc;
            },
          ),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    showDialog<ProductEntity>(
                      context: context,
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider<InventoryBloc>.value(value: bloc),
                          BlocProvider<SettingsBloc>.value(
                            value: context.read<SettingsBloc>(),
                          ),
                        ],
                        child: ProductFormDialog(product: product),
                      ),
                    ).then(results.add),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String barcode = '123456789012',
    String name = 'Test Product',
    String purchasePrice = '5.00',
    String price = '10.00',
    String stock = '5',
  }) async {
    await tester.enterText(find.widgetWithText(TextField, 'الباركود'), barcode);
    await tester.enterText(find.widgetWithText(TextField, 'اسم المنتج'), name);
    await tester.enterText(
      find.widgetWithText(TextField, _purchasePriceLabel),
      purchasePrice,
    );
    await tester.enterText(find.widgetWithText(TextField, 'السعر'), price);
    await tester.enterText(find.widgetWithText(TextField, 'المخزون'), stock);
  }

  testWidgets('should show purchase price field when opened', (tester) async {
    await openDialog(tester);

    expect(find.text(_newProductTitle), findsOneWidget);
    expect(find.widgetWithText(TextField, _purchasePriceLabel), findsOneWidget);
  });

  testWidgets('should populate purchase price when editing existing product', (
    tester,
  ) async {
    const product = ProductEntity(
      barcode: '123456789012',
      name: 'Test Product',
      price: 10.0,
      purchasePrice: 7.5,
      stock: 5,
    );
    await tester.pumpWidget(buildTestWidget(product: product));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, _purchasePriceLabel),
    );
    expect(field.controller!.text, '7.50');
  });

  testWidgets(
    'should submit entity with purchasePrice when purchase price is below selling price',
    (tester) async {
      await openDialog(tester);
      await fillForm(tester);

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      expect(find.text(_purchasePriceWarning), findsNothing);
      expect(results.length, 1);
      final entity = results.single!;
      expect(entity.barcode, '123456789012');
      expect(entity.name, 'Test Product');
      expect(entity.price, 10.0);
      expect(entity.purchasePrice, 5.0);
      expect(entity.stock, 5);
    },
  );

  testWidgets(
    'should show warning and block submission when purchase price exceeds selling price',
    (tester) async {
      await openDialog(tester);
      await fillForm(tester, purchasePrice: '15.00', price: '10.00');

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      // Warning dialog is displayed and the form is NOT popped yet.
      expect(find.text(_purchasePriceWarning), findsOneWidget);
      expect(find.text(_newProductTitle), findsOneWidget);
      expect(results, isEmpty);

      // Dismissing the warning cancels submission entirely.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text(_cancelButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(results, isEmpty);
      expect(find.text(_newProductTitle), findsOneWidget);
    },
  );

  testWidgets('should submit with purchase price after confirming warning', (
    tester,
  ) async {
    await openDialog(tester);
    await fillForm(tester, purchasePrice: '15.00', price: '10.00');

    await tester.tap(find.text(_addButton));
    await tester.pumpAndSettle();

    expect(find.text(_purchasePriceWarning), findsOneWidget);
    await tester.tap(find.text(_purchasePriceWarningProceed));
    await tester.pumpAndSettle();

    expect(results.length, 1);
    final entity = results.single!;
    expect(entity.price, 10.0);
    expect(entity.purchasePrice, 15.0);
  });
}
