import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';

import '../../helpers/fake_receipts_repository.dart';
import '../../helpers/fake_refunds_repository.dart';
import '../../../../features/inventory/helpers/fake_inventory_repository.dart';
import '../../../../helpers/default_receipt.dart';
import '../../../../helpers/default_product.dart';

class FakeAuthRepository implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async => Right([]);
  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async => Right(null);
  @override
  Future<Either<Failure, void>> save(UserEntity user) async => const Right(null);
  @override
  Future<Either<Failure, void>> delete(String username) async => const Right(null);
  @override
  Future<Either<Failure, bool>> isSetupCompleted() async => const Right(true);
  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async => const Right(null);
  @override
  Future<Either<Failure, void>> retrySeeding() async => const Right(null);
}

void main() {
  group('ReceiptsBloc', () {
    late FakeReceiptsRepository receiptsRepo;
    late FakeInventoryRepository inventoryRepo;
    late FakeRefundsRepository refundsRepo;
    late FakeAuthRepository authRepo;
    late ReceiptsBloc bloc;

    setUp(() {
      receiptsRepo = FakeReceiptsRepository();
      inventoryRepo = FakeInventoryRepository();
      refundsRepo = FakeRefundsRepository();
      authRepo = FakeAuthRepository();
      bloc = ReceiptsBloc(
        receiptsRepo: receiptsRepo,
        inventoryRepo: inventoryRepo,
        refundsRepo: refundsRepo,
        authRepo: authRepo,
        getCurrentShiftId: () => 's1',
        generateId: () => 'test-receipt-id',
      );
    });

    tearDown(() {
      bloc.close();
    });

    group('initial state', () {
      test('should have initial status and no receipts', () {
        expect(bloc.state.status, ReceiptBlocStatus.initial);
        expect(bloc.state.receipts, isNull);
        expect(bloc.state.failure, isNull);
      });
    });

    group('CreateReceipt', () {
      test('should save receipt, update stock, and emit ready', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 10),
        );
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '222', name: 'Notebook', stock: 5),
        );

        bloc.add(CreateReceipt(
          shiftId: 's1',
          orderNumber: 'ORD-00001',
          items: const [
            ReceiptItem(name: 'Pen', barcode: '111', quantity: 2, unitPricePiastres: 1500),
            ReceiptItem(name: 'Notebook', barcode: '222', quantity: 1, unitPricePiastres: 3000),
          ],
          subtotalPiastres: 6000,
          discountPiastres: 500,
          taxPiastres: 0,
          totalPiastres: 5500,
          username: 'cashier1',
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.length == 1 &&
                s.receipts!.first.id == 'test-receipt-id' &&
                s.receipts!.first.shiftId == 's1' &&
                s.receipts!.first.orderNumber == 'ORD-00001' &&
                s.receipts!.first.stockUpdated == true &&
                s.receipts!.first.status == ReceiptStatus.active &&
                s.receipts!.first.username == 'cashier1' &&
                s.receipts!.first.subtotalPiastres == 6000 &&
                s.receipts!.first.discountPiastres == 500 &&
                s.receipts!.first.totalPiastres == 5500),
          ]),
        );
      });

      test('should emit error when receipt save fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(const CreateReceipt(
          shiftId: 's1',
          orderNumber: 'ORD-00001',
          items: [],
          subtotalPiastres: 0,
          totalPiastres: 0,
          username: 'cashier1',
        ));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null &&
                s.failure is DatabaseFailure),
          ]),
        );

        failingBloc.close();
      });

      test('should emit error when stock update fails', () async {
        bloc.add(CreateReceipt(
          shiftId: 's1',
          orderNumber: 'ORD-00001',
          items: const [
            ReceiptItem(name: 'Pen', barcode: '111', quantity: 2, unitPricePiastres: 1500),
          ],
          subtotalPiastres: 3000,
          totalPiastres: 3000,
          username: 'cashier1',
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null),
          ]),
        );
      });
    });

    group('LoadReceipts', () {
      test('should load all receipts', () async {
        await receiptsRepo.save(
          defaultReceipt(id: 'r1', shiftId: 's1', orderNumber: 'ORD-001'),
        );
        await receiptsRepo.save(
          defaultReceipt(id: 'r2', shiftId: 's1', orderNumber: 'ORD-002'),
        );

        bloc.add(const LoadReceipts());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.length == 2),
          ]),
        );
      });

      test('should emit error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(const LoadReceipts());

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadReceiptsByMonth', () {
      test('should filter receipts by year and month', () async {
        final janDate = DateTime(2026, 1, 15);
        final febDate = DateTime(2026, 2, 10);

        await receiptsRepo.save(
          defaultReceipt(id: 'r1', shiftId: 's1', orderNumber: 'ORD-001', createdAt: janDate),
        );
        await receiptsRepo.save(
          defaultReceipt(id: 'r2', shiftId: 's1', orderNumber: 'ORD-002', createdAt: febDate),
        );
        await receiptsRepo.save(
          defaultReceipt(id: 'r3', shiftId: 's1', orderNumber: 'ORD-003', createdAt: janDate),
        );

        bloc.add(const LoadReceiptsByMonth(year: 2026, month: 1));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.length == 2 &&
                s.receipts!.every((r) => r.orderNumber.startsWith('ORD-00') && (r.orderNumber == 'ORD-001' || r.orderNumber == 'ORD-003'))),
          ]),
        );
      });

      test('should emit error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(const LoadReceiptsByMonth(year: 2026, month: 1));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });

    group('ProcessRefund', () {
      test('should save refund, update status to returned, restore stock, emit ready', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 5),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(name: 'Pen', barcode: '111', quantity: 2, unitPricePiastres: 1500),
            ],
            subtotalPiastres: 3000, totalPiastres: 3000,
            createdAt: DateTime(2026, 1, 1), username: 'cashier1',
            status: ReceiptStatus.active, stockUpdated: true,
          ),
        );

        bloc.add(const LoadReceipts());
        await bloc.stream.firstWhere((s) => s.status == ReceiptBlocStatus.ready);
        final receipt = bloc.state.receipts!.first;

        bloc.add(ProcessRefund(
          receipt: receipt,
          type: RefundType.full,
          amountRestored: 3000,
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.length == 1 &&
                s.receipts!.first.status == ReceiptStatus.returned),
          ]),
        );

        expect(refundsRepo.savedRefunds.length, 1);
        expect(refundsRepo.savedRefunds.first.originalReceiptId, 'r1');
        expect(refundsRepo.savedRefunds.first.type, RefundType.full);
        expect(refundsRepo.savedRefunds.first.amountRestored, 3000);
      });

      test('should emit RefundLockFailure when receipt is not active', () async {
        final returnedReceipt = ReceiptEntity(
          id: 'r2', shiftId: 's1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 0,
          createdAt: DateTime(2026, 1, 1), username: 'cashier1',
          status: ReceiptStatus.returned, stockUpdated: true,
        );

        bloc.add(ProcessRefund(
          receipt: returnedReceipt,
          type: RefundType.full,
          amountRestored: 0,
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure is RefundLockFailure),
          ]),
        );
      });

      test('should emit error when refund save fails', () async {
        final failingRefundRepo = FakeRefundsRepository();
        failingRefundRepo.shouldFail = true;
        final failingBloc = ReceiptsBloc(
          receiptsRepo: receiptsRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: failingRefundRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        final activeReceipt = ReceiptEntity(
          id: 'r3', shiftId: 's1', orderNumber: 'ORD-003',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 0,
          createdAt: DateTime(2026, 1, 1), username: 'cashier1',
          status: ReceiptStatus.active, stockUpdated: true,
        );

        failingBloc.add(ProcessRefund(
          receipt: activeReceipt,
          type: RefundType.full,
          amountRestored: 0,
        ));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });

    group('ModifyReceipt', () {
      test('should update items, adjust stock delta, set status to modified, emit ready', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 10),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(name: 'Pen', barcode: '111', quantity: 5, unitPricePiastres: 1500),
            ],
            subtotalPiastres: 7500, totalPiastres: 7500,
            createdAt: DateTime(2026, 1, 1), username: 'cashier1',
            status: ReceiptStatus.active, stockUpdated: true,
          ),
        );
        bloc.add(const LoadReceipts());
        await bloc.stream.firstWhere((s) => s.status == ReceiptBlocStatus.ready);
        final receipt = bloc.state.receipts!.first;

        bloc.add(ModifyReceipt(
          receipt: receipt,
          items: const [
            ReceiptItem(name: 'Pen', barcode: '111', quantity: 3, unitPricePiastres: 1500),
          ],
          subtotalPiastres: 4500,
          discountPiastres: 0,
          taxPiastres: 0,
          totalPiastres: 4500,
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.first.items.length == 1 &&
                s.receipts!.first.items.first.quantity == 3 &&
                s.receipts!.first.totalPiastres == 4500 &&
                s.receipts!.first.status == ReceiptStatus.modified &&
                s.receipts!.first.modificationCount == 1),
          ]),
        );
      });

      test('should emit error when receipt is already returned', () async {
        final returnedReceipt = ReceiptEntity(
          id: 'r2', shiftId: 's1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 0,
          createdAt: DateTime(2026, 1, 1), username: 'cashier1',
          status: ReceiptStatus.returned, stockUpdated: true,
        );

        bloc.add(ModifyReceipt(
          receipt: returnedReceipt,
          items: const [],
          subtotalPiastres: 0,
          discountPiastres: 0,
          taxPiastres: 0,
          totalPiastres: 0,
        ));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>((s) => s.status == ReceiptBlocStatus.loading),
            predicate<ReceiptsState>((s) =>
                s.status == ReceiptBlocStatus.error &&
                s.failure != null),
          ]),
        );
      });
    });
  });
}


