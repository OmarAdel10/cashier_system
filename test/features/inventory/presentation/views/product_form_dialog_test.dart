import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
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

const _addButton = 'إضافة';
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

  Widget buildTestWidget({
    ProductEntity? product,
    AppSettingsEntity settings = const AppSettingsEntity(),
    List<String> categories = const [],
  }) {
    return MaterialApp(
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
    String price = '10.00',
    String stock = '5',
  }) async {
    final barcodeField = find.widgetWithText(TextField, 'الباركود');
    if (barcodeField.evaluate().isNotEmpty) {
      await tester.enterText(barcodeField, barcode);
    }
    await tester.enterText(find.widgetWithText(TextField, 'اسم المنتج'), name);
    await tester.enterText(find.widgetWithText(TextField, 'السعر'), price);
    final stockField = find.widgetWithText(TextField, 'المخزون');
    if (stockField.evaluate().isNotEmpty) {
      await tester.enterText(stockField, stock);
    }
  }

  testWidgets('should show new product form when opened', (tester) async {
    await openDialog(tester);

    expect(find.text(_newProductTitle), findsOneWidget);
  });

  testWidgets('should submit entity with form values', (tester) async {
    await openDialog(tester);
    await fillForm(tester);

    await tester.tap(find.text(_addButton));
    await tester.pumpAndSettle();

    expect(results.length, 1);
    final entity = results.single!;
    expect(entity.barcode, '123456789012');
    expect(entity.name, 'Test Product');
    expect(entity.price, 10.0);
    expect(entity.stock, 5);
  });

  group('category dropdown', () {
    const cafeSettings = AppSettingsEntity(businessType: 'cafe');

    testWidgets('shows dropdown with categories for F&B business type', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          settings: cafeSettings,
          categories: ['hot drinks', 'cold drinks'],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);

      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('hot drinks'), findsOneWidget);
      expect(find.text('cold drinks'), findsOneWidget);
      expect(find.text('بدون فئة'), findsOneWidget);
    });

    testWidgets('hides dropdown for retail business type', (tester) async {
      await openDialog(tester);

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('submits selected category on save', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          settings: cafeSettings,
          categories: ['hot drinks', 'cold drinks'],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await fillForm(tester);

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('hot drinks').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      expect(results.length, 1);
      expect(results.single!.category, 'hot drinks');
    });

    testWidgets('submits null category when nothing selected', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(settings: cafeSettings, categories: ['hot drinks']),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await fillForm(tester);

      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      expect(results.length, 1);
      expect(results.single!.category, isNull);
    });
  });

  group('tile color auto-select', () {
    const cafeSettings = AppSettingsEntity(
      businessType: 'cafe',
      favoritesStripEnabled: true,
    );

    testWidgets('auto-selects first color when no quick tiles exist', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(settings: cafeSettings));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);

      await fillForm(tester);
      await tester.tap(find.text(_addButton));
      await tester.pumpAndSettle();

      final entity = results.single!;
      expect(entity.isQuickTile, isTrue);
      expect(entity.tileColorHex, '#007ACC');
    });

    testWidgets('auto-selects first color when last tile has no color', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(settings: cafeSettings));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
