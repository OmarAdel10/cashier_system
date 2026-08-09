import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/station_form_dialog.dart';
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
import '../../../checkout/helpers/fake_station_repository.dart';
import '../../../checkout/helpers/fake_table_repositories.dart';
import '../../../checkout/helpers/fake_zone_repository.dart';
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
        BlocProvider<CategoryBloc>(
          create: (_) {
            final cBloc = CategoryBloc(repository: FakeCategoryRepository());
            cBloc.add(const LoadCategories());
            return cBloc;
          },
        ),
      ],
      child: const InventoryWorkspace(),
    ),
  );
}

Widget _buildPlaystationWidget(
  InventoryBloc bloc, {
  List<StationEntity> stations = const [],
}) {
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
        BlocProvider<CategoryBloc>(
          create: (_) {
            final cBloc = CategoryBloc(repository: FakeCategoryRepository());
            cBloc.add(const LoadCategories());
            return cBloc;
          },
        ),
        BlocProvider<StationBloc>(
          create: (_) =>
              StationBloc(repository: FakeStationRepository(stations))
                ..add(const LoadStations()),
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
  List<ZoneEntity> zones = const [],
  List<TableEntity> tables = const [],
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
        BlocProvider<ZoneBloc>(
          create: (_) =>
              ZoneBloc(repository: FakeZoneRepository(zones))
                ..add(const LoadZones()),
        ),
        BlocProvider<TableBloc>(
          create: (_) => TableBloc(
            tableRepository: FakeTableRepository(tables),
            roundRepository: FakeRoundRepository(),
          )..add(const LoadTables()),
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

    group('playstation station + flat product sections', () {
      final psProducts = [
        const ProductEntity(
          barcode: 'ps1',
          name: 'CoD Session',
          price: 75.0,
          isQuickTile: true,
        ),
        const ProductEntity(barcode: 'ps2', name: 'FIFA Session', price: 60.0),
      ];

      StationEntity station(
        String id,
        String name, {
        StationStatus status = StationStatus.available,
      }) {
        return StationEntity(
          id: id,
          name: name,
          parentCategory: 'Backroom',
          stationType: StationType.playstation,
          normalHourlyRate: 100,
          multiHourlyRate: 150,
          minimumGameCostNormal: 1,
          minimumGameCostMulti: 1,
          iconAsset: 'assets/icons/ps4.svg',
          status: status,
        );
      }

      Future<void> pumpLoaded(
        WidgetTester tester, {
        List<StationEntity> stations = const [],
      }) async {
        bloc.add(const LoadInventory());
        await tester.pumpWidget(
          _buildPlaystationWidget(bloc, stations: stations),
        );
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();
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
      }

      testWidgets(
        'renders stations section and flat products with per-hour prices',
        (tester) async {
          await pumpLoaded(
            tester,
            stations: [
              station('s1', 'PS4-1'),
              station('s2', 'PS4-2', status: StationStatus.active),
            ],
          );

          // Stations section on top with management tiles.
          expect(find.text('PS4-1'), findsOneWidget);
          expect(find.text('PS4-2'), findsOneWidget);
          final stationTiles = find.widgetWithIcon(
            ListTile,
            PhosphorIcons.gameController,
          );
          expect(find.byType(ListTile), findsWidgets);
          expect(
            find.descendant(
              of: stationTiles,
              matching: find.byIcon(PhosphorIcons.pencilSimple),
            ),
            findsNWidgets(2),
          );
          expect(
            find.descendant(
              of: stationTiles,
              matching: find.byIcon(PhosphorIcons.trash),
            ),
            findsNWidgets(2),
          );
          // Products section below with its own header title.
          expect(find.text('المنتجات'), findsOneWidget);
          // Flat list: both products each with /hr.
          expect(find.byType(ProductCard), findsNWidgets(2));
          expect(find.textContaining('فى الساعة'), findsNWidgets(2));
          // No quick-tiles section title, no category columns.
          expect(find.textContaining('المنتجات السريعة'), findsNothing);
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

      testWidgets('app bar plus opens station form', (tester) async {
        await pumpLoaded(tester);

        // SectionCard renders the body before its header actions, so the
        // section-level plus is the last plus in the tree.
        await tester.tap(find.byIcon(PhosphorIcons.plus).last);
        await tester.pumpAndSettle();

        expect(find.byType(StationFormDialog), findsOneWidget);
      });

      testWidgets('products section plus opens product form', (tester) async {
        await pumpLoaded(tester);

        await tester.tap(find.byKey(const Key('inventoryProductsAdd')));
        await tester.pumpAndSettle();

        expect(find.text('منتج جديد'), findsOneWidget);
      });

      testWidgets('delete on active station shows blocked snackbar', (
        tester,
      ) async {
        await pumpLoaded(
          tester,
          stations: [station('s1', 'PS4-1', status: StationStatus.active)],
        );

        await tester.tap(
          find.descendant(
            of: find.widgetWithIcon(ListTile, PhosphorIcons.gameController),
            matching: find.byIcon(PhosphorIcons.trash),
          ),
        );
        await tester.pump();

        expect(find.textContaining('لا يمكن حذف'), findsOneWidget);
      });
    });

    group('cafe tables and zones management', () {
      const zoneA = ZoneEntity(id: 'z1', name: 'Zone A');
      const zoneB = ZoneEntity(
        id: 'z2',
        name: 'Zone B',
        kind: ZoneKind.takeaway,
      );

      Future<void> pumpLoaded(WidgetTester tester) async {
        await tester.pumpWidget(
          _buildCafeWidget(
            bloc,
            categories: ['hot drinks'],
            zones: const [zoneA, zoneB],
          ),
        );
        bloc.add(const LoadInventory());
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();
      }

      testWidgets('renders tables section with empty state and zone manager', (
        tester,
      ) async {
        await pumpLoaded(tester);

        expect(find.text('الطاولات والمناطق'), findsOneWidget);
        expect(find.textContaining('لا توجد طاولات'), findsOneWidget);
        expect(find.byKey(const Key('manageZonesButton')), findsOneWidget);
        expect(find.byKey(const Key('addTableButton')), findsOneWidget);
      });

      testWidgets('adds a table through the form dialog', (tester) async {
        await pumpLoaded(tester);

        await tester.tap(find.byKey(const Key('addTableButton')));
        await tester.pumpAndSettle();
        expect(find.text('طاولة جديدة'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'اسم الطاولة'),
          'Table 1',
        );
        await tester.tap(find.text('إضافة'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Table 1'), findsOneWidget);
        expect(find.textContaining('Zone A'), findsOneWidget);
      });

      testWidgets('lists tables with zone name and room badge', (tester) async {
        await tester.pumpWidget(
          _buildCafeWidget(
            bloc,
            zones: const [zoneA],
            tables: const [
              TableEntity(
                id: 't1',
                name: 'VIP',
                zoneId: 'z1',
                capacity: 6,
                isRoom: true,
              ),
            ],
          ),
        );
        bloc.add(const LoadInventory());
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('VIP'), findsOneWidget);
        expect(find.textContaining('Zone A'), findsOneWidget);
        expect(find.textContaining('غرفة'), findsOneWidget);
      });

      testWidgets('delete on occupied table shows blocked snackbar', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildCafeWidget(
            bloc,
            zones: const [zoneA],
            tables: const [
              TableEntity(
                id: 't1',
                name: 'Busy',
                zoneId: 'z1',
                status: TableStatus.orderPending,
              ),
            ],
          ),
        );
        bloc.add(const LoadInventory());
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.widgetWithIcon(ListTile, PhosphorIcons.table),
            matching: find.byIcon(PhosphorIcons.trash),
          ),
        );
        await tester.pump();

        expect(find.textContaining('لا يمكن حذف طاولة'), findsOneWidget);
      });

      testWidgets('manage zones dialog opens and deletes a zone', (
        tester,
      ) async {
        await pumpLoaded(tester);

        await tester.tap(find.byKey(const Key('manageZonesButton')));
        await tester.pumpAndSettle();

        expect(find.text('إدارة المناطق'), findsOneWidget);
        expect(find.text('Zone A'), findsOneWidget);
        expect(find.text('Zone B'), findsOneWidget);

        await tester.tap(find.byKey(const Key('zoneDelete_z1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('حذف').last);
        await tester.pumpAndSettle();

        expect(find.text('Zone A'), findsNothing);
      });
    });
  });
}
