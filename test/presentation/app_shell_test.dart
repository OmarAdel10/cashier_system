import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_state.dart';
import 'package:cashier_system/features/auth/presentation/widgets/end_shift_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/inventory/data/models/app_product_model.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/receipts/data/models/app_receipt_model.dart';
import 'package:cashier_system/features/receipts/data/models/app_refund_model.dart';
import 'package:cashier_system/features/receipts/data/models/receipt_item_adapter.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_state.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/presentation/app_shell.dart';
import '../features/auth/helpers/fake_auth_repository.dart';
import '../features/auth/helpers/fake_shifts_repository.dart';
import '../features/inventory/helpers/fake_inventory_repository.dart';
import '../features/receipts/helpers/fake_receipts_repository.dart';
import '../features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

final _testUser = UserEntity(
  username: 'cashier1',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.cashier,
  createdAt: DateTime.now(),
);

Widget _buildTestApp() {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = SettingsBloc(repository: FakeSettingsRepository());
            bloc.add(const LoadSettings());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) {
            final bloc = InventoryBloc(repository: FakeInventoryRepository());
            bloc.add(const LoadInventory());
            return bloc;
          },
        ),
        BlocProvider(create: (_) => CheckoutBloc()),
        BlocProvider(
          create: (_) => AuthBloc(
            repository: FakeAuthRepository(),
          )..add(const CheckAuth()),
        ),
        BlocProvider(
          create: (_) => ShiftBloc(
            repository: FakeShiftsRepository(),
          ),
        ),
        BlocProvider(
          create: (_) => SalesBloc(
            receiptsRepo: FakeReceiptsRepository(),
          ),
        ),
      ],
      child: AppShell(user: _testUser),
    ),
  );
}

/// Wraps pre-created blocs into the widget tree using [BlocProvider.value].
/// Caller must call [addTearDown] on each bloc for cleanup.
Widget _buildTestAppFromBlocs({
  required ShiftBloc shiftBloc,
  required SettingsBloc settingsBloc,
  required InventoryBloc inventoryBloc,
  required CheckoutBloc checkoutBloc,
  required AuthBloc authBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settingsBloc),
        BlocProvider.value(value: inventoryBloc),
        BlocProvider.value(value: checkoutBloc),
        BlocProvider.value(value: authBloc),
        BlocProvider.value(value: shiftBloc),
        BlocProvider(
          create: (_) => SalesBloc(
            receiptsRepo: FakeReceiptsRepository(),
          ),
        ),
      ],
      child: AppShell(user: _testUser),
    ),
  );
}

/// Simulates a settings repository that always fails on load.
class FakeFailingSettingsRepository implements ISettingsRepository {
  @override
  Future<Either<Failure, AppSettingsEntity>> getSettings() async {
    return Left(DatabaseFailure('Sync failed'));
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings) async {
    return const Right(null);
  }
}

void main() {
  setUpAll(() async {
    Hive.init('test/_hive_test_app_shell');
    Hive.registerAdapter(AppProductModelAdapter());
    Hive.registerAdapter(AppReceiptModelAdapter());
    Hive.registerAdapter(AppRefundModelAdapter());
    Hive.registerAdapter(ReceiptItemAdapter());
  });

  setUp(() async {
    HydratedBloc.storage = _MockStorage();
    await Hive.openBox<AppProductModel>('inventory');
    await Hive.openBox<AppReceiptModel>('receipts');
    await Hive.openBox<AppRefundModel>('refunds');
  });

  tearDown(() async {
    await Hive.box<AppProductModel>('inventory').close();
    await Hive.box<AppReceiptModel>('receipts').close();
    await Hive.box<AppRefundModel>('refunds').close();
    await Hive.deleteBoxFromDisk('inventory');
    await Hive.deleteBoxFromDisk('receipts');
    await Hive.deleteBoxFromDisk('refunds');
  });

  group('AppShell', () {
    testWidgets('renders 4 nav items in the rail', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIcons.shoppingCartSimple), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.package), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.chartBar), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.gearSix), findsOneWidget);
    });

    testWidgets('shows SettingsWorkspace when settings nav is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.gearSix));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders receipt tower panel on checkout view',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('الفاتورة'), findsAtLeastNWidgets(1));
    });

    testWidgets('should show active shift indicator', (tester) async {
      final shiftBloc = ShiftBloc(repository: FakeShiftsRepository());
      final settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
      final inventoryBloc = InventoryBloc(repository: FakeInventoryRepository());
      final checkoutBloc = CheckoutBloc();
      final authBloc = AuthBloc(repository: FakeAuthRepository());

      addTearDown(shiftBloc.close);
      addTearDown(settingsBloc.close);
      addTearDown(inventoryBloc.close);
      addTearDown(checkoutBloc.close);
      addTearDown(authBloc.close);

      settingsBloc.add(const LoadSettings());
      inventoryBloc.add(const LoadInventory());
      authBloc.add(const CheckAuth());

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestAppFromBlocs(
        shiftBloc: shiftBloc,
        settingsBloc: settingsBloc,
        inventoryBloc: inventoryBloc,
        checkoutBloc: checkoutBloc,
        authBloc: authBloc,
      ));

      // AppShell dispatches StartShift in initState.
      // pumpAndSettle waits for the async bloc processing + rebuilds.
      await tester.pumpAndSettle();

      // End shift icon indicates active shift controls are rendered.
      expect(find.byIcon(PhosphorIcons.signOut), findsOneWidget);

      // Verify bloc reached active status.
      expect(shiftBloc.state.status, ShiftStatus.active);
      expect(shiftBloc.state.shift, isNotNull);
    });

    testWidgets('should show sync status', (tester) async {
      // Simulate a settings sync failure.
      final settingsBloc =
          SettingsBloc(repository: FakeFailingSettingsRepository());
      final shiftBloc = ShiftBloc(repository: FakeShiftsRepository());
      final inventoryBloc = InventoryBloc(repository: FakeInventoryRepository());
      final checkoutBloc = CheckoutBloc();
      final authBloc = AuthBloc(repository: FakeAuthRepository());

      addTearDown(settingsBloc.close);
      addTearDown(shiftBloc.close);
      addTearDown(inventoryBloc.close);
      addTearDown(checkoutBloc.close);
      addTearDown(authBloc.close);

      // Trigger sync error.
      settingsBloc.add(const LoadSettings());
      inventoryBloc.add(const LoadInventory());
      authBloc.add(const CheckAuth());

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestAppFromBlocs(
        shiftBloc: shiftBloc,
        settingsBloc: settingsBloc,
        inventoryBloc: inventoryBloc,
        checkoutBloc: checkoutBloc,
        authBloc: authBloc,
      ));
      await tester.pumpAndSettle();

      // Error state is reached.
      expect(settingsBloc.state.status, SettingsStatus.error);
      expect(settingsBloc.state.failure, isNotNull);

      // App shell remains stable (does not crash, nav is still rendered).
      expect(find.byIcon(PhosphorIcons.shoppingCartSimple), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.package), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.chartBar), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.gearSix), findsOneWidget);
    });

    testWidgets('should show end shift dialog', (tester) async {
      final shiftBloc = ShiftBloc(repository: FakeShiftsRepository());
      final settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
      final inventoryBloc = InventoryBloc(repository: FakeInventoryRepository());
      final checkoutBloc = CheckoutBloc();
      final authBloc = AuthBloc(repository: FakeAuthRepository());

      addTearDown(shiftBloc.close);
      addTearDown(settingsBloc.close);
      addTearDown(inventoryBloc.close);
      addTearDown(checkoutBloc.close);
      addTearDown(authBloc.close);

      settingsBloc.add(const LoadSettings());
      inventoryBloc.add(const LoadInventory());
      authBloc.add(const CheckAuth());

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestAppFromBlocs(
        shiftBloc: shiftBloc,
        settingsBloc: settingsBloc,
        inventoryBloc: inventoryBloc,
        checkoutBloc: checkoutBloc,
        authBloc: authBloc,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.signOut));
      await tester.pumpAndSettle();

      // EndShiftDialog should be displayed.
      expect(find.byType(EndShiftDialog), findsOneWidget);

      // Dialog content.
      expect(
        find.text('Are you sure you want to end your shift?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      // Both the dialog title and the confirm button contain 'End Shift'.
      expect(find.text('End Shift'), findsAtLeastNWidgets(1));
    });
  });
}
