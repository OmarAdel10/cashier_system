import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/audit/audit_service.dart';
import 'package:cashier_system/features/auth/data/models/app_shift_model.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/checkout/data/models/app_station_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_session_record_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_table_round_model.dart';
import 'package:cashier_system/features/checkout/data/models/app_zone_model.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/views/checkout_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/views/station_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/views/table_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_tower_panel.dart';
import 'package:cashier_system/features/expenses/data/models/app_expense_model.dart';
import 'package:cashier_system/features/inventory/data/models/app_product_model.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/receipts/data/models/app_receipt_model.dart';
import 'package:cashier_system/features/receipts/data/models/app_refund_model.dart';
import 'package:cashier_system/features/receipts/data/models/receipt_item_adapter.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/presentation/app_shell.dart';
import '../features/auth/helpers/fake_auth_repository.dart';
import '../features/auth/helpers/fake_shifts_repository.dart';
import '../features/inventory/helpers/fake_inventory_repository.dart';
import '../features/receipts/helpers/fake_receipts_repository.dart';
import '../features/settings/helpers/fake_settings_repository.dart';

/// Table-billing wiring checks for AppShell. Lives in its own file and its
/// own Hive directory: the AppShell ZoneBloc/TableBloc load futures run on
/// real Hive boxes, and sharing the app_shell test file's box lifecycle
/// caused intermittent hangs (boxes closed+deleted by earlier tests, then
/// reopened inside test fake-async).
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

Widget _buildCafeShell() {
  final settingsRepo = FakeSettingsRepository();
  settingsRepo.saveSettings(
    AppSettingsEntity(languageCode: 'en', businessType: 'cafe'),
  );
  return RepositoryProvider<AuditService>.value(
    value: AuditService(box: Hive.lazyBox<String>('audit_test_tables')),
    child: RepositoryProvider<IAuthRepository>.value(
      value: FakeAuthRepository(),
      child: MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) {
                final bloc = SettingsBloc(repository: settingsRepo);
                bloc.add(const LoadSettings());
                return bloc;
              },
            ),
            BlocProvider(
              create: (_) {
                final bloc = InventoryBloc(
                  repository: FakeInventoryRepository(),
                );
                bloc.add(const LoadInventory());
                return bloc;
              },
            ),
            BlocProvider(create: (_) => CheckoutBloc()),
            BlocProvider(
              create: (_) =>
                  AuthBloc(repository: FakeAuthRepository())
                    ..add(const CheckAuth()),
            ),
            BlocProvider(
              create: (_) => ShiftBloc(repository: FakeShiftsRepository()),
            ),
            BlocProvider(
              create: (_) => SalesBloc(
                receiptsRepo: FakeReceiptsRepository(),
                shiftsRepo: FakeShiftsRepository(),
              ),
            ),
          ],
          child: AppShell(user: _testUser),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    Hive.init('test/_hive_test_app_shell_tables');
    Hive.registerAdapter(AppProductModelAdapter());
    Hive.registerAdapter(AppReceiptModelAdapter());
    Hive.registerAdapter(AppRefundModelAdapter());
    Hive.registerAdapter(ReceiptItemAdapter());
    Hive.registerAdapter(AppShiftModelAdapter());
    Hive.registerAdapter(AppStationModelAdapter());
    Hive.registerAdapter(AppSessionRecordModelAdapter());
    Hive.registerAdapter(AppZoneModelAdapter());
    Hive.registerAdapter(AppTableModelAdapter());
    Hive.registerAdapter(AppTableRoundModelAdapter());
    Hive.registerAdapter(AppExpenseModelAdapter());
    await Hive.openBox<AppProductModel>('inventory');
    await Hive.openLazyBox<AppReceiptModel>('receipts');
    await Hive.openLazyBox<AppRefundModel>('refunds');
    await Hive.openBox<AppShiftModel>('shifts');
    await Hive.openBox<String>('active_shifts');
    await Hive.openBox<AppStationModel>('stations');
    await Hive.openBox<AppSessionRecordModel>('session_records');
    await Hive.openBox<AppZoneModel>('floor_zones');
    await Hive.openBox<AppTableModel>('tables');
    await Hive.openBox<AppTableRoundModel>('table_rounds');
    await Hive.openLazyBox<AppExpenseModel>('expenses');
    await Hive.openLazyBox<String>('audit_test_tables');
  });

  setUp(() async {
    HydratedBloc.storage = _MockStorage();
  });

  // Boxes stay open for the whole file (opened in setUpAll) so all
  // repository reads are in-memory. Closing/reopening boxes between tests
  // recreates box files on disk and intermittently hangs the test runner.

  group('AppShell table billing', () {
    testWidgets('table mode renders table workspace without tower panel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildCafeShell());
      await tester.pumpAndSettle();

      expect(find.byType(TableWorkspace), findsOneWidget);
      expect(find.byType(CheckoutWorkspace), findsNothing);
      expect(find.byType(StationWorkspace), findsNothing);
      expect(find.byType(CheckoutTowerPanel), findsNothing);
    });
  });
}
