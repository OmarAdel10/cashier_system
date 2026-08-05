import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/modification_entry_dialog.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';
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

class _NoopReceiptsRepo extends Fake implements IReceiptsRepository {
  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll({int? limit}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(
    String shiftId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(
    int year,
    int month,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async =>
      const Right([]);
}

class _NoopInventoryRepo extends Fake implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async =>
      const Right({});

  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> updateTileColor(
    String barcode,
    String colorHex,
  ) async => const Right(null);

  @override
  Future<Either<Failure, void>> updateStock(
    String barcode,
    int deltaQuantity,
  ) async => const Right(null);
}

class _NoopRefundsRepo extends Fake implements IRefundsRepository {
  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(
    String receiptId,
  ) async => const Right([]);
}

class _MockAuthRepo implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async => const Right([]);

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> save(UserEntity user) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> delete(String username) async =>
      const Right(null);
  @override
  Future<Either<Failure, bool>> isSetupCompleted() async => const Right(true);
  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> retrySeeding() async => const Right(null);
}

class _MockReceiptsBloc extends ReceiptsBloc {
  _MockReceiptsBloc()
    : super(
        receiptsRepo: _NoopReceiptsRepo(),
        inventoryRepo: _NoopInventoryRepo(),
        refundsRepo: _NoopRefundsRepo(),
        authRepo: _MockAuthRepo(),
        getCurrentShiftId: () => 's1',
        generateId: () => 'test-id',
      );

  @override
  void add(ReceiptsEvent event) {}

  void setState(ReceiptsState state) => emit(state);
}

class _CapturingBloc extends _MockReceiptsBloc {
  ReceiptsEvent? capturedEvent;

  @override
  void add(ReceiptsEvent event) {
    capturedEvent = event;
    super.add(event);
  }
}

_MockReceiptsBloc _makeBloc() => _MockReceiptsBloc();

Future<void> _showDialog(
  WidgetTester tester, {
  required ReceiptEntity receipt,
  required SettingsBloc settingsBloc,
  required ReceiptsBloc receiptsBloc,
  bool isAuthorized = false,
  String? adminUsername,
  String? adminPassword,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
        ],
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider<SettingsBloc>.value(value: settingsBloc),
                      BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
                    ],
                    child: Scaffold(
                      body: ModificationEntryDialog(
                        receipt: receipt,
                        isAuthorized: isAuthorized,
                        adminUsername: adminUsername,
                        adminPassword: adminPassword,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Show Dialog'));
  await tester.pump();
}

void main() {
  late SettingsBloc settingsBloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    settingsBloc.add(const LanguageToggled('en'));
  });

  tearDown(() {
    settingsBloc.close();
  });

  group('ModificationEntryDialog', () {
    final receipt = defaultReceipt(
      orderNumber: 'ORD-001',
      items: [
        const ReceiptItem(
          name: 'Pen',
          barcode: '111',
          quantity: 2,
          unitPricePiastres: 1500,
        ),
        const ReceiptItem(
          name: 'Notebook',
          barcode: '222',
          quantity: 1,
          unitPricePiastres: 5000,
        ),
      ],
      subtotalPiastres: 8000,
      discountPiastres: 500,
      taxPiastres: 750,
      totalPiastres: 8250,
    );

    testWidgets('renders items with quantity fields', (tester) async {
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Modify Receipt'), findsOneWidget);
      expect(find.text('Order No.: ORD-001'), findsOneWidget);
      expect(find.text('Pen'), findsOneWidget);
      expect(find.text('Notebook'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('EGP 80.00'), findsOneWidget);
    });

    testWidgets('changing quantity updates subtotal', (tester) async {
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: _makeBloc(),
      );

      final qtyFields = find.byType(TextField);
      await tester.enterText(qtyFields.first, '5');
      await tester.pump();

      expect(find.text('EGP 125.00'), findsOneWidget);
    });

    testWidgets('delta indicator shows +N green and -N red', (tester) async {
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: _makeBloc(),
      );

      final qtyFields = find.byType(TextField);

      await tester.enterText(qtyFields.first, '5');
      await tester.pump();
      expect(find.text('+3'), findsOneWidget);

      await tester.enterText(qtyFields.first, '1');
      await tester.pump();
      expect(find.text('-1'), findsOneWidget);

      await tester.enterText(qtyFields.first, '2');
      await tester.pump();
      expect(find.text('+3'), findsNothing);
      expect(find.text('-1'), findsNothing);
    });

    testWidgets('save shows loading indicator', (tester) async {
      final bloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: bloc,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      bloc.close();
    });

    testWidgets('BlocListener pops dialog on ready', (tester) async {
      final bloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: bloc,
      );

      expect(find.byType(Dialog), findsOneWidget);
      bloc.setState(const ReceiptsState(status: ReceiptBlocStatus.ready));
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);

      bloc.close();
    });

    testWidgets('BlocListener shows error snackbar on failure', (tester) async {
      final bloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: bloc,
      );

      bloc.setState(
        ReceiptsState(
          status: ReceiptBlocStatus.error,
          failure: const RefundLockFailure(
            'Cannot modify a receipt with status returned',
            receiptId: 'r1',
            currentStatus: ReceiptStatus.returned,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Cannot modify a receipt with status returned'),
        findsOneWidget,
      );

      bloc.close();
    });

    testWidgets('cancel button pops dialog', (tester) async {
      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets(
      'save dispatches ModifyReceipt with recalculated discount and tax',
      (tester) async {
        final bloc = _CapturingBloc();
        await _showDialog(
          tester,
          receipt: receipt,
          settingsBloc: settingsBloc,
          receiptsBloc: bloc,
        );

        final qtyFields = find.byType(TextField);
        await tester.enterText(qtyFields.first, '5');
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pump();

        final event = bloc.capturedEvent;
        expect(event, isA<ModifyReceipt>());
        final modify = event as ModifyReceipt;
        expect(modify.subtotalPiastres, equals(12500));
        expect(modify.discountPiastres, equals(781));
        expect(modify.taxPiastres, equals(1172));
        expect(modify.totalPiastres, equals(12891));
        bloc.close();
      },
    );

    testWidgets('save with zero discount and tax keeps them zero', (
      tester,
    ) async {
      final noDiscountReceipt = defaultReceipt(
        orderNumber: 'ORD-002',
        items: const [
          ReceiptItem(
            name: 'Pen',
            barcode: '111',
            quantity: 2,
            unitPricePiastres: 1500,
          ),
        ],
        subtotalPiastres: 3000,
        discountPiastres: 0,
        taxPiastres: 0,
        totalPiastres: 3000,
      );

      final bloc = _CapturingBloc();
      await _showDialog(
        tester,
        receipt: noDiscountReceipt,
        settingsBloc: settingsBloc,
        receiptsBloc: bloc,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      final event = bloc.capturedEvent;
      expect(event, isA<ModifyReceipt>());
      final modify = event as ModifyReceipt;
      expect(modify.discountPiastres, equals(0));
      expect(modify.taxPiastres, equals(0));
      expect(modify.totalPiastres, equals(3000));
      bloc.close();
    });
  });
}
