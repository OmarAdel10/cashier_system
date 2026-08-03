import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/checkout_confirmation_dialog.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

class _MockAuthRepo implements IAuthRepository {
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

class _MockReceiptsBloc extends ReceiptsBloc {
  _MockReceiptsBloc()
      : super(
          receiptsRepo: _NoopReceiptsRepo(),
          inventoryRepo: _NoopInventoryRepo(),
          refundsRepo: _NoopRefundsRepo(),
          authRepo: _MockAuthRepo(),
          getCurrentShiftId: () => 'shift-1',
          generateId: () => 'test-id',
        );

  void setState(ReceiptsState state) {
    emit(state);
  }
}

Future<void> _showDialogInTest(
  WidgetTester tester, {
  required ReceiptsBloc receiptsBloc,
  required SettingsBloc settingsBloc,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
        ],
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider<SettingsBloc>.value(value: settingsBloc),
                  BlocProvider<ReceiptsBloc>.value(value: receiptsBloc),
                ],
                child: const CheckoutConfirmationDialog(),
              ),
            );
          },
          child: const Text('Show Dialog'),
        ),
      );
    }),
  ));

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

  group('CheckoutConfirmationDialog', () {
    testWidgets('loading phase renders spinner', (tester) async {
      final bloc = _MockReceiptsBloc();
      bloc.setState(ReceiptsState(status: ReceiptBlocStatus.loading));

      await _showDialogInTest(tester,
          receiptsBloc: bloc, settingsBloc: settingsBloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing sale...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      bloc.close();
    });

    testWidgets('success phase auto-dismisses', (tester) async {
      final bloc = _MockReceiptsBloc();
      bloc.setState(ReceiptsState(status: ReceiptBlocStatus.loading));

      await _showDialogInTest(tester,
          receiptsBloc: bloc, settingsBloc: settingsBloc);

      bloc.setState(ReceiptsState(status: ReceiptBlocStatus.ready));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(Dialog), findsNothing);

      bloc.close();
    });

    testWidgets('failure phase shows error with dismiss button after 3 seconds',
        (tester) async {
      final bloc = _MockReceiptsBloc();
      final failure = DatabaseFailure('Database error');
      bloc.setState(
          ReceiptsState(status: ReceiptBlocStatus.error, failure: failure));

      await _showDialogInTest(tester,
          receiptsBloc: bloc, settingsBloc: settingsBloc);

      expect(find.text('Database error'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      bloc.close();
    });

    testWidgets('failure phase auto-dismisses after 5 seconds',
        (tester) async {
      final bloc = _MockReceiptsBloc();
      final failure = DatabaseFailure('Database error');
      bloc.setState(ReceiptsState(status: ReceiptBlocStatus.error, failure: failure));

      await _showDialogInTest(tester,
          receiptsBloc: bloc, settingsBloc: settingsBloc);

      expect(find.text('Database error'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));

      expect(find.byType(Dialog), findsNothing);

      bloc.close();
    });
  });
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
          String shiftId) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(
          int year, int month) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(
          DateTime date) async =>
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
      String barcode, String colorHex) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateStock(
      String barcode, int deltaQuantity) async {
    return const Right(null);
  }
}

class _NoopRefundsRepo extends Fake implements IRefundsRepository {
  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(
          String receiptId) async =>
      const Right([]);
}
