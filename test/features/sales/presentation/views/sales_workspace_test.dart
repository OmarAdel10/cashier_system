import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/status_badge.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_event.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import 'package:cashier_system/features/sales/presentation/views/sales_workspace.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../settings/helpers/fake_settings_repository.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';
import '../../../../helpers/default_receipt.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

class _ManualSalesBloc extends SalesBloc {
  _ManualSalesBloc() : super(receiptsRepo: FakeReceiptsRepository());

  @override
  void add(SalesEvent event) {}

  void setState(SalesState state) => emit(state);
}

class _CapturingSalesBloc extends SalesBloc {
  final List<SalesEvent> capturedEvents = [];

  _CapturingSalesBloc() : super(receiptsRepo: FakeReceiptsRepository());

  @override
  void add(SalesEvent event) {
    capturedEvents.add(event);
  }

  void setState(SalesState state) => emit(state);
}

class _NoopShiftRepo implements IShiftsRepository {
  final ShiftEntity? activeShift;

  _NoopShiftRepo({this.activeShift});

  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async => Right(activeShift);

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async => const Right([]);

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async => const Right(null);
}

class _NoopAuthRepo implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async => const Right([]);

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async => const Right(null);

  @override
  Future<Either<Failure, void>> save(UserEntity user) async => const Right(null);

  @override
  Future<Either<Failure, void>> delete(String username) async => const Right(null);
  @override
  Future<Either<Failure, bool>> isSetupCompleted() async => const Right(true);
  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async => const Right(null);
}

class _NoopInventoryRepo extends Fake implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async => const Right({});

  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async => const Right(null);

  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async => const Right(null);

  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async => const Right([]);

  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async => const Right(null);

  @override
  Future<Either<Failure, void>> updateTileColor(String barcode, String colorHex) async => const Right(null);

  @override
  Future<Either<Failure, void>> updateStock(String barcode, int deltaQuantity) async => const Right(null);
}

class _NoopRefundsRepo extends Fake implements IRefundsRepository {
  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async => const Right(null);

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(String receiptId) async => const Right([]);
}

class _NoopReceiptsRepo extends Fake implements IReceiptsRepository {
  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async => const Right(null);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll() async => const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(String shiftId) async => const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(int year, int month) async => const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async => const Right([]);
}

ReceiptsBloc _createNoopReceiptsBloc() {
  return ReceiptsBloc(
    receiptsRepo: _NoopReceiptsRepo(),
    inventoryRepo: _NoopInventoryRepo(),
    refundsRepo: _NoopRefundsRepo(),
    authRepo: _NoopAuthRepo(),
  );
}

final _noopReceiptsBloc = _createNoopReceiptsBloc();

final _adminUser = UserEntity(
  username: 'admin',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.admin,
  createdAt: DateTime.now(),
);

final _cashierUser = UserEntity(
  username: 'cashier1',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.cashier,
  createdAt: DateTime.now(),
);

void main() {
  late SettingsBloc settingsBloc;
  late ReceiptsBloc _defaultReceiptsBloc;

  Widget _buildApp({
    required Widget child,
    required SettingsBloc settingsBloc,
    required SalesBloc salesBloc,
    required ShiftBloc shiftBloc,
    ReceiptsBloc? receiptsBloc,
    AuthBloc? authBloc,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<SalesBloc>.value(value: salesBloc),
            BlocProvider<ShiftBloc>.value(value: shiftBloc),
            BlocProvider<ReceiptsBloc>.value(
              value: receiptsBloc ?? _defaultReceiptsBloc,
            ),
            if (authBloc != null)
              BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: child,
        ),
      ),
    );
  }

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    settingsBloc.add(const LanguageToggled('en'));
    _defaultReceiptsBloc = _createNoopReceiptsBloc();
  });

  tearDown(() {
    settingsBloc.close();
    _defaultReceiptsBloc.close();
  });

  Future<void> _pumpWithSize(WidgetTester tester, Widget widget) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(widget);
  }

  group('SalesWorkspace', () {
    testWidgets('shows loading state when status is loading with no summary', (tester) async {
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(const SalesState(status: SalesStatus.loading));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();
      expect(find.text('Loading sales...'), findsOneWidget);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('shows error state with retry button', (tester) async {
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(const SalesState(status: SalesStatus.error));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();
      expect(find.text('Failed to load sales'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('admin view shows summary bar and month browser', (tester) async {
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(SalesState(
        status: SalesStatus.ready,
        todaySummary: const TodaySummary(
          totalPiastres: 15000,
          receiptCount: 3,
          itemsSold: 7,
        ),
        months: [
          const MonthData(year: 2026, month: 3, totalPiastres: 40000, receiptCount: 10),
        ],
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await _pumpWithSize(tester, _buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();

      expect(find.text('Total'), findsWidgets);
      expect(find.text('EGP 150.00'), findsWidgets);
      expect(find.text('Receipts'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Items Sold'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      expect(find.text('March 2026'), findsOneWidget);
      expect(find.text('10 Receipts'), findsOneWidget);
      expect(find.text('EGP 400.00'), findsOneWidget);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('cashier view shows shift receipt list', (tester) async {
      final salesBloc = _ManualSalesBloc();
      final receipt = defaultReceipt(
        id: 'r1',
        orderNumber: 'ORD-001',
        items: [
          const ReceiptItem(name: 'Pen', barcode: '111', quantity: 2, unitPricePiastres: 1500),
        ],
        subtotalPiastres: 3000,
        totalPiastres: 3000,
      );
      salesBloc.setState(SalesState(
        status: SalesStatus.ready,
        todaySummary: const TodaySummary(totalPiastres: 3000, receiptCount: 1, itemsSold: 2),
        shiftReceipts: [receipt],
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _cashierUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();
      await tester.pump();

      expect(find.text('ORD-001'), findsOneWidget);
      expect(find.text('EGP 30.00'), findsOneWidget);
      expect(find.byType(StatusBadge), findsWidgets);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('cashier view shows empty state when no receipts', (tester) async {
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(const SalesState(
        status: SalesStatus.ready,
        todaySummary: TodaySummary(totalPiastres: 0, receiptCount: 0, itemsSold: 0),
        shiftReceipts: [],
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _cashierUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();

      expect(find.text('My Sales (This Shift)'), findsOneWidget);
      expect(find.text('No sales yet this shift'), findsOneWidget);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('admin view shows summary bar with zeros when summary is null', (tester) async {
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(const SalesState(
        status: SalesStatus.ready,
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await _pumpWithSize(tester, _buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();

      expect(find.text('Total'), findsWidgets);
      expect(find.text('EGP 0.00'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      // MonthCards show loading state - check for month names
      expect(find.textContaining('2026'), findsWidgets);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('admin view expands month card to show receipts', (tester) async {
      final receipt = defaultReceipt(
        id: 'r1', orderNumber: 'ORD-100',
        items: [
          const ReceiptItem(name: 'Pen', barcode: '111', quantity: 2, unitPricePiastres: 1500),
        ],
        subtotalPiastres: 3000, totalPiastres: 3000,
        createdAt: DateTime(2026, 3, 15, 10, 30),
      );
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(SalesState(
        status: SalesStatus.ready,
        todaySummary: const TodaySummary(totalPiastres: 3000, receiptCount: 1, itemsSold: 2),
        months: [
          MonthData(year: 2026, month: 3, totalPiastres: 3000, receiptCount: 1, receipts: [receipt]),
        ],
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await _pumpWithSize(tester, _buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();

      // Tap to expand March 2026 card
      await tester.tap(find.text('March 2026'));
      await tester.pump();

      expect(find.text('ORD-100'), findsOneWidget);
      expect(find.textContaining('10:30'), findsOneWidget);
      expect(find.byType(StatusBadge), findsWidgets);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('cashier view shows StatusBadge per receipt', (tester) async {
      final receipt = defaultReceipt(
        id: 'r1', orderNumber: 'ORD-001',
        items: [
          const ReceiptItem(name: 'Pen', barcode: '111', quantity: 1, unitPricePiastres: 1000),
        ],
        subtotalPiastres: 1000, totalPiastres: 1000,
      );
      final salesBloc = _ManualSalesBloc();
      salesBloc.setState(SalesState(
        status: SalesStatus.ready,
        todaySummary: const TodaySummary(totalPiastres: 1000, receiptCount: 1, itemsSold: 1),
        shiftReceipts: [receipt],
      ));
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _cashierUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
      ));

      await tester.pump();

      expect(find.byType(StatusBadge), findsOneWidget);

      salesBloc.close();
      shiftBloc.close();
    });

    testWidgets('BlocListener triggers data load when ReceiptsBloc becomes ready', (tester) async {
      final salesBloc = _CapturingSalesBloc();
      final shiftBloc = ShiftBloc(repository: _NoopShiftRepo());

      await tester.pumpWidget(_buildApp(
        child: SalesWorkspace(user: _adminUser),
        settingsBloc: settingsBloc,
        salesBloc: salesBloc,
        shiftBloc: shiftBloc,
        receiptsBloc: _defaultReceiptsBloc,
      ));

      await tester.pump();

      // ReceiptsBloc starts with initial status, so when it becomes ready
      // the listener should fire.
      _defaultReceiptsBloc.add(const LoadReceipts());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(salesBloc.capturedEvents.any((e) => e is LoadTodaySummary), isTrue);
      expect(salesBloc.capturedEvents.any((e) => e is LoadMonth), isTrue);

      salesBloc.close();
      shiftBloc.close();
    });
  });
}
