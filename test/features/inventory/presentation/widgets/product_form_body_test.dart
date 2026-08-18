import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/helpers/barcode_generator.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_event.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/views/product_form_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../helpers/fake_category_repository.dart';
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

const _barcodeLabel = 'الباركود';
const _saveBarcodeLabel = 'حفظ الباركود';
const _printBarcodeLabel = 'طباعة الباركود';
const _stockLabel = 'المخزون';
const _priceLabel = 'السعر';
const _pricePerHourLabel = 'السعر لكل ساعة';
const _quickTileLabel = 'بلاطة سريعة';
const _favoriteLabel = 'مفضلة';
const _addButton = 'إضافة';

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

  Future<void> openDialog(
    WidgetTester tester, {
    AppSettingsEntity settings = const AppSettingsEntity(),
    List<String> categories = const [],
    ProductEntity? product,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<InventoryBloc>.value(value: bloc),
            BlocProvider<SettingsBloc>(
              create: (_) {
                final sBloc = SettingsBloc(
                  repository: FakeSettingsRepository(settings),
                );
                sBloc.add(const LoadSettings());
                return sBloc;
              },
            ),
            BlocProvider<CategoryBloc>(
              create: (_) {
                final cBloc = CategoryBloc(
                  repository: FakeCategoryRepository(categories),
                );
                cBloc.add(const LoadCategories());
                return cBloc;
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
                            BlocProvider<CategoryBloc>.value(
                              value: context.read<CategoryBloc>(),
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
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Test Product',
    String price = '10.00',
  }) async {
    await tester.enterText(find.widgetWithText(TextField, 'اسم المنتج'), name);
    await tester.enterText(find.widgetWithText(TextField, 'السعر'), price);
  }

  Future<void> fillFormPriced(
    WidgetTester tester, {
    String name = 'Test Product',
    String price = '10.00',
  }) async {
    await tester.enterText(find.widgetWithText(TextField, 'اسم المنتج'), name);
    await tester.enterText(
      find.widgetWithText(TextField, _pricePerHourLabel),
      price,
    );
  }

  group('retail fields unchanged', () {
    testWidgets('barcode and stock fields present', (tester) async {
      await openDialog(tester);

      expect(find.widgetWithText(TextField, _barcodeLabel), findsOneWidget);
      expect(find.widgetWithText(TextField, _stockLabel), findsOneWidget);
    });

    testWidgets('barcode export action visible with valid barcode', (
      tester,
    ) async {
      // Editing product: barcode preloaded at dialog build.
      await openDialog(
        tester,
        product: const ProductEntity(
          barcode: '123456789012',
          name: 'Widget',
          price: 10,
        ),
      );
      await tester.pump();

      // Barcode export/label-print action visible in retail (default print).
      expect(find.text(_printBarcodeLabel), findsOneWidget);
    });
  });

  group('cafe mode', () {
    const cafeSettings = AppSettingsEntity(
      businessType: 'cafe',
      favoritesStripEnabled: true,
    );

    testWidgets('hides barcode and stock fields, shows favorite toggle', (
      tester,
    ) async {
      await openDialog(tester, settings: cafeSettings);

      expect(find.widgetWithText(TextField, _barcodeLabel), findsNothing);
      expect(find.widgetWithText(TextField, _stockLabel), findsNothing);
      expect(find.text(_favoriteLabel), findsOneWidget);
      expect(find.text(_quickTileLabel), findsNothing);
    });

    testWidgets('barcode export action hidden in grid mode', (tester) async {
      await openDialog(tester, settings: cafeSettings);
      await fillForm(tester);

      await tester.pump();
      // Barcode export/label-print action hidden in grid modes.
      expect(find.text(_saveBarcodeLabel), findsNothing);
    });

    testWidgets('submit generates auto barcode for new product', (
      tester,
    ) async {
      await openDialog(tester, settings: cafeSettings);
      await fillForm(tester);

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      expect(results.length, 1);
      final entity = results.single!;
      expect(isAutoBarcode(entity.barcode), isTrue);
      expect(entity.stock, 0);
    });
  });

  group('playstation mode', () {
    const playstationSettings = AppSettingsEntity(businessType: 'playstation');

    testWidgets('price per hour label and hidden fields', (tester) async {
      await openDialog(tester, settings: playstationSettings);

      expect(
        find.widgetWithText(TextField, _pricePerHourLabel),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, _priceLabel), findsNothing);
      expect(find.widgetWithText(TextField, _barcodeLabel), findsNothing);
      expect(find.widgetWithText(TextField, _stockLabel), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text(_favoriteLabel), findsNothing);
      expect(find.text(_quickTileLabel), findsNothing);
    });

    testWidgets('submit generates auto barcode for new product', (
      tester,
    ) async {
      await openDialog(tester, settings: playstationSettings);
      await fillFormPriced(tester);

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      expect(results.length, 1);
      final entity = results.single!;
      expect(isAutoBarcode(entity.barcode), isTrue);
      expect(entity.category, isNull);
    });
  });
}
