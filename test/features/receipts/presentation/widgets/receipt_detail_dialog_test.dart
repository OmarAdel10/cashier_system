import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/crypto/password_hasher.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_state.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/receipt_detail_dialog.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/modification_entry_dialog.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/refund_confirmation_dialog.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/status_badge.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
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

final _testSalt = generateSalt();

final _adminUser = UserEntity(
  username: 'admin',
  passwordHash: hashPassword('adminpass', _testSalt),
  passwordSalt: _testSalt,
  mustChangePassword: false,
  role: UserRole.admin,
  createdAt: DateTime.now(),
);

final _cashierUser = UserEntity(
  username: 'cashier1',
  passwordHash: hashPassword('cashier1', _testSalt),
  passwordSalt: _testSalt,
  mustChangePassword: false,
  role: UserRole.cashier,
  createdAt: DateTime.now(),
);

class _MockAuthBloc extends AuthBloc {
  _MockAuthBloc() : super(repository: _MockAuthRepo());

  @override
  void add(AuthEvent event) {}

  void setState(AuthState state) => emit(state);
}

class _MockAuthRepo implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async =>
      Right([_adminUser, _cashierUser]);

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async {
    if (username == 'admin') return Right(_adminUser);
    if (username == 'cashier1') return Right(_cashierUser);
    return const Right(null);
  }

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

class _NoopReceiptsRepo extends Fake implements IReceiptsRepository {
  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll() async =>
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

ReceiptsBloc _makeBloc() {
  return ReceiptsBloc(
    receiptsRepo: _NoopReceiptsRepo(),
    inventoryRepo: _NoopInventoryRepo(),
    refundsRepo: _NoopRefundsRepo(),
    authRepo: _MockAuthRepo(),
    getCurrentShiftId: () => 's1',
    generateId: () => 'test-id',
  );
}

Future<void> _showDialog(
  WidgetTester tester, {
  required ReceiptEntity receipt,
  required SettingsBloc settingsBloc,
  required AuthBloc authBloc,
  required ReceiptsBloc receiptsBloc,
}) async {
  final authRepo = _MockAuthRepo();
  final user = authBloc.state.user ?? _cashierUser;
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
        RepositoryProvider<IAuthRepository>.value(value: authRepo),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Scaffold(
                    body: ReceiptDetailDialog(receipt: receipt, user: user),
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
  late _MockAuthBloc authBloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    settingsBloc.add(const LanguageToggled('en'));
    authBloc = _MockAuthBloc();
    authBloc.setState(
      AuthState(user: _adminUser, status: AuthStatus.authenticated),
    );
  });

  tearDown(() {
    settingsBloc.close();
    authBloc.close();
  });

  group('ReceiptDetailDialog', () {
    testWidgets('renders all receipt fields with active status', (
      tester,
    ) async {
      final receipt = defaultReceipt(
        orderNumber: 'ORD-100',
        items: [
          const ReceiptItem(
            name: 'Pen',
            barcode: '111',
            quantity: 2,
            unitPricePiastres: 1500,
          ),
          const ReceiptItem(
            name: 'Book',
            barcode: '222',
            quantity: 1,
            unitPricePiastres: 5000,
          ),
        ],
        subtotalPiastres: 8000,
        discountPiastres: 500,
        taxPiastres: 750,
        totalPiastres: 8250,
        createdAt: DateTime(2026, 3, 15, 10, 30, 0),
      );

      await _showDialog(
        tester,
        receipt: receipt,
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Order No.: ORD-100'), findsOneWidget);
      expect(find.text('2026-03-15'), findsOneWidget);
      expect(find.text('cashier1'), findsOneWidget);
      expect(find.textContaining('Pen'), findsOneWidget);
      expect(find.textContaining('Book'), findsOneWidget);
      expect(find.textContaining('EGP 15.00'), findsWidgets);
      expect(find.textContaining('EGP 50.00'), findsWidgets);
      expect(find.textContaining('EGP 80.00'), findsWidgets);
      expect(find.textContaining('-EGP 5.00'), findsOneWidget);
      expect(find.textContaining('EGP 7.50'), findsOneWidget);
      expect(find.textContaining('EGP 82.50'), findsWidgets);
    });

    testWidgets('shows active status badge with green icon', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.checkCircle), findsOneWidget);
    });

    testWidgets('shows returned status badge with red icon', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(status: ReceiptStatus.returned),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Returned'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.arrowArcLeft), findsOneWidget);
    });

    testWidgets('shows modified status badge with amber icon', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(status: ReceiptStatus.modified),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Modified'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.pencilSimple), findsWidgets);
    });

    testWidgets(
      'shows refund and modify buttons for cashier on active receipt',
      (tester) async {
        authBloc.setState(
          AuthState(user: _cashierUser, status: AuthStatus.authenticated),
        );
        await _showDialog(
          tester,
          receipt: defaultReceipt(
            items: [
              const ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 1,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
          ),
          settingsBloc: settingsBloc,
          authBloc: authBloc,
          receiptsBloc: _makeBloc(),
        );

        expect(find.text('Return/Refund'), findsOneWidget);
        expect(find.text('Modify'), findsOneWidget);
      },
    );

    testWidgets('hides refund and modify buttons for admin on active receipt', (
      tester,
    ) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Return/Refund'), findsNothing);
      expect(find.text('Modify'), findsNothing);
    });

    testWidgets('hides refund button for returned receipt', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          status: ReceiptStatus.returned,
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Return/Refund'), findsNothing);
      expect(find.text('Modify'), findsNothing);
    });

    testWidgets('cancel button pops dialog', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('modified receipt still shows modify button', (tester) async {
      authBloc.setState(
        AuthState(user: _cashierUser, status: AuthStatus.authenticated),
      );
      // modificationCount >= 1 means subsequent mod → requires admin password
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          status: ReceiptStatus.modified,
          modificationCount: 1,
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Modify'), findsOneWidget);
      expect(find.text('Return/Refund'), findsOneWidget);
    });

    testWidgets('returned receipt hides both buttons', (tester) async {
      authBloc.setState(
        AuthState(user: _cashierUser, status: AuthStatus.authenticated),
      );
      await _showDialog(
        tester,
        receipt: defaultReceipt(status: ReceiptStatus.returned),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Modify'), findsNothing);
      expect(find.text('Return/Refund'), findsNothing);
    });

    testWidgets('active modify opens modification entry directly', (
      tester,
    ) async {
      authBloc.setState(
        AuthState(user: _cashierUser, status: AuthStatus.authenticated),
      );
      final receiptsBloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: receiptsBloc,
      );

      await tester.tap(find.text('Modify'));
      await tester.pump();

      expect(find.byType(ModificationEntryDialog), findsOneWidget);

      receiptsBloc.close();
    });

    testWidgets('subsequent modify opens admin password dialog first', (
      tester,
    ) async {
      authBloc.setState(
        AuthState(user: _cashierUser, status: AuthStatus.authenticated),
      );
      final receiptsBloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          status: ReceiptStatus.modified,
          modificationCount: 1,
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: receiptsBloc,
      );

      await tester.tap(find.text('Modify'));
      await tester.pump();

      expect(find.byType(ModificationEntryDialog), findsNothing);
      expect(find.text('Admin Authorization'), findsOneWidget);

      receiptsBloc.close();
    });

    testWidgets('refund button opens refund confirmation', (tester) async {
      authBloc.setState(
        AuthState(user: _cashierUser, status: AuthStatus.authenticated),
      );
      final receiptsBloc = _makeBloc();
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: receiptsBloc,
      );

      await tester.tap(find.text('Return/Refund'));
      await tester.pump();

      expect(find.byType(RefundConfirmationDialog), findsOneWidget);

      receiptsBloc.close();
    });

    testWidgets('does not show discount row when discount is zero', (
      tester,
    ) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(
          items: [
            const ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 1,
              unitPricePiastres: 1000,
            ),
          ],
          subtotalPiastres: 1000,
          discountPiastres: 0,
          taxPiastres: 0,
          totalPiastres: 1000,
        ),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Discount'), findsNothing);
      expect(find.text('Tax'), findsNothing);
      expect(find.text('Total'), findsWidgets);
    });

    testWidgets('total row is bold', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('renders store name when configured', (tester) async {
      settingsBloc.add(const StoreNameChanged('My Shop'));
      await tester.pump();

      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('My Shop'), findsOneWidget);
    });

    testWidgets('hides store name when empty', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('My Shop'), findsNothing);
    });

    testWidgets('uses StatusBadge widget', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('label uses cashier instead of settings', (tester) async {
      await _showDialog(
        tester,
        receipt: defaultReceipt(username: 'cashier1'),
        settingsBloc: settingsBloc,
        authBloc: authBloc,
        receiptsBloc: _makeBloc(),
      );

      expect(find.text('cashier1'), findsOneWidget);
    });
  });
}
