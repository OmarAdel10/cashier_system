import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_event.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/inventory/presentation/views/inventory_workspace.dart';
import 'package:cashier_system/features/inventory/presentation/widgets/product_card.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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

Widget _buildTestWidget(InventoryBloc bloc) {
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
      child: const InventoryWorkspace(),
    ),
  );
}

Widget _buildPlaystationWidget(InventoryBloc bloc) {
  return MaterialApp(
    builder: (context, child) => MultiBlocProvider(
      providers: [
        BlocProvider<InventoryBloc>.value(value: bloc),
        BlocProvider<SettingsBloc>(
          create: (_) {
            final sBloc = SettingsBloc(repository: FakeSettingsRepository());
            sBloc.add(const BusinessTypeChanged('playstation'));
            return sBloc;
          },
        ),
      ],
      child: child!,
    ),
    home: const InventoryWorkspace(),
  );
}

Widget _buildCafeWidget(
  InventoryBloc bloc, {
  bool favoritesStripEnabled = true,
  List<String> categories = const [],
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<InventoryBloc>.value(value: bloc),
        BlocProvider<SettingsBloc>(
          create: (_) {
            final sBloc = SettingsBloc(
              repository: FakeSettingsRepository(
                AppSettingsEntity(
                  businessType: 'cafe',
                  favoritesStripEnabled: favoritesStripEnabled,
                ),
              ),
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
      child: const InventoryWorkspace(),
    ),
  );
}

void main() {
  late InventoryBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = InventoryBloc(repository: FakeInventoryRepository());
  });

  tearDown(() {
    bloc.close();
  });

  group('InventoryWorkspace', () {
    testWidgets('should show loading indicator initially', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show empty state when no products', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      bloc.add(const LoadInventory());
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      expect(find.text('اضغط + لإضافة أول منتج'), findsOneWidget);
    });

    testWidgets('should show product card after adding product', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      bloc.add(const LoadInventory());
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();

      bloc.add(
        const AddProduct(
          barcode: '123456789012',
          name: 'Test Product',
          price: 9.99,
          stock: 5,
        ),
      );
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.textContaining('123456789012'), findsOneWidget);
      expect(find.textContaining('9.99'), findsOneWidget);
      expect(find.textContaining('المخزون: 5'), findsOneWidget);
    });

    testWidgets('should show title and add button in section header', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('المخزون'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.plus), findsOneWidget);
    });

    group('cafe three-column layout', () {
      const products = [
        ProductEntity(
          barcode: 'c1',
          name: 'Latte',
          price: 40,
          category: 'hot drinks',
        ),
        ProductEntity(
          barcode: 'c2',
          name: 'Espresso',
          price: 30,
          category: 'hot drinks',
        ),
        ProductEntity(
          barcode: 'c3',
          name: 'Iced Tea',
          price: 25,
          category: 'cold drinks',
        ),
        ProductEntity(
          barcode: 'f1',
          name: 'Croissant',
          price: 20,
          isQuickTile: true,
        ),
      ];

      Future<void> pumpLoaded(WidgetTester tester) async {
        await tester.pumpWidget(
          _buildCafeWidget(bloc, categories: ['hot drinks', 'cold drinks']),
        );
        bloc.add(const LoadInventory());
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();
        for (final p in products) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          bloc.add(
            AddProduct(
              barcode: p.barcode,
              name: p.name,
              price: p.price,
              isQuickTile: p.isQuickTile,
              category: p.category,
            ),
          );
        }
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();
      }

      testWidgets('renders categorized, uncategorized, favorites columns', (
        tester,
      ) async {
        await pumpLoaded(tester);

        expect(find.textContaining('مصنفة (3)'), findsOneWidget);
        expect(find.textContaining('غير مصنفة (1)'), findsOneWidget);
        expect(find.textContaining('المفضلة (1)'), findsOneWidget);
        expect(find.text('Latte'), findsOneWidget);
        expect(find.text('Espresso'), findsOneWidget);
        // Second category group is lazily built below the fold.
        await tester.scrollUntilVisible(
          find.text('Iced Tea'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(InventoryWorkspace),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('cold drinks'), findsOneWidget);
        expect(find.text('Iced Tea'), findsOneWidget);
        // Favorite without category appears in Uncategorized AND Favorites.
        expect(find.text('Croissant'), findsNWidgets(2));
      });

      testWidgets('hides favorites column when strip is disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildCafeWidget(bloc, favoritesStripEnabled: false),
        );
        bloc.add(const LoadInventory());
        for (final p in products) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          bloc.add(
            AddProduct(
              barcode: p.barcode,
              name: p.name,
              price: p.price,
              isQuickTile: p.isQuickTile,
              category: p.category,
            ),
          );
        }
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('مصنفة (3)'), findsOneWidget);
        expect(find.textContaining('غير مصنفة (1)'), findsOneWidget);
        // Favorite without strip still shows in Uncategorized.
        expect(find.text('Croissant'), findsOneWidget);
        expect(find.textContaining('المفضلة'), findsNothing);
      });
    });

    group('playstation flat product list', () {
      final psProducts = [
        const ProductEntity(
          barcode: 'ps1',
          name: 'CoD Session',
          price: 75.0,
          isQuickTile: true,
        ),
        const ProductEntity(barcode: 'ps2', name: 'FIFA Session', price: 60.0),
      ];

      testWidgets(
        'renders all products in one flat list with per-hour prices',
        (tester) async {
          bloc.add(const LoadInventory());
          await tester.pumpWidget(_buildPlaystationWidget(bloc));
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          for (final p in psProducts) {
            bloc.add(
              AddProduct(
                barcode: p.barcode,
                name: p.name,
                price: p.price,
                isQuickTile: p.isQuickTile,
              ),
            );
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 50)),
            );
          }
          await tester.pump();
          await tester.pump();

          expect(find.text('CoD Session'), findsOneWidget);
          expect(find.text('FIFA Session'), findsOneWidget);
          // No quick-tiles section title, no category columns.
          expect(find.textContaining('المنتجات السريعة'), findsNothing);
          // Flat list: both products side by side vertically, each with /hr.
          expect(find.byType(ProductCard), findsNWidgets(2));
          expect(find.textContaining('فى الساعة'), findsNWidgets(2));
        },
      );

      testWidgets('shows empty state when no products', (tester) async {
        bloc.add(const LoadInventory());
        await tester.pumpWidget(_buildPlaystationWidget(bloc));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('لا توجد منتجات'), findsOneWidget);
      });

      testWidgets('add product via plus button opens product form', (
        tester,
      ) async {
        bloc.add(const LoadInventory());
        await tester.pumpWidget(_buildPlaystationWidget(bloc));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(PhosphorIcons.plus));
        await tester.pumpAndSettle();

        expect(find.text('منتج جديد'), findsOneWidget);
      });
    });
  });
}
