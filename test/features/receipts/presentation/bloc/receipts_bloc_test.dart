import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';

import '../../helpers/fake_receipts_repository.dart';
import '../../helpers/fake_refunds_repository.dart';
import '../../../../features/inventory/helpers/fake_inventory_repository.dart';

void main() {
  group('ReceiptsBloc', () {
    late FakeReceiptsRepository receiptsRepo;
    late FakeInventoryRepository inventoryRepo;
    late FakeRefundsRepository refundsRepo;
    late ReceiptsBloc bloc;

    setUp(() {
      receiptsRepo = FakeReceiptsRepository();
      inventoryRepo = FakeInventoryRepository();
      refundsRepo = FakeRefundsRepository();
      bloc = ReceiptsBloc(
        receiptsRepo: receiptsRepo,
        inventoryRepo: inventoryRepo,
        refundsRepo: refundsRepo,
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
          _product(barcode: '111', name: 'Pen', stock: 10),
        );

        bloc.add(CreateReceipt(
          shiftId: 'shift-1',
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
                s.receipts!.first.shiftId == 'shift-1' &&
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
          generateId: () => 'test-id',
        );

        failingBloc.add(const CreateReceipt(
          shiftId: 'shift-1',
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

      test('should still emit ready when stock update fails (step 2 failure does not roll back)', () async {
        bloc.add(CreateReceipt(
          shiftId: 'shift-1',
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
                s.status == ReceiptBlocStatus.ready &&
                s.receipts != null &&
                s.receipts!.length == 1 &&
                s.receipts!.first.stockUpdated == true),
          ]),
        );
      });
    });

    group('LoadReceipts', () {
      test('should load all receipts', () async {
        await receiptsRepo.save(
          _makeReceipt(id: 'r1', shiftId: 's1', orderNumber: 'ORD-001'),
        );
        await receiptsRepo.save(
          _makeReceipt(id: 'r2', shiftId: 's1', orderNumber: 'ORD-002'),
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
          _makeReceipt(id: 'r1', shiftId: 's1', orderNumber: 'ORD-001', createdAt: janDate),
        );
        await receiptsRepo.save(
          _makeReceipt(id: 'r2', shiftId: 's1', orderNumber: 'ORD-002', createdAt: febDate),
        );
        await receiptsRepo.save(
          _makeReceipt(id: 'r3', shiftId: 's1', orderNumber: 'ORD-003', createdAt: janDate),
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
  });
}

ReceiptEntity _makeReceipt({
  required String id,
  required String shiftId,
  required String orderNumber,
  DateTime? createdAt,
}) {
  return ReceiptEntity(
    id: id,
    shiftId: shiftId,
    orderNumber: orderNumber,
    items: const [],
    subtotalPiastres: 0,
    totalPiastres: 0,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    username: 'cashier1',
  );
}

ProductEntity _product({
  required String barcode,
  required String name,
  int stock = 0,
}) {
  return ProductEntity(
    barcode: barcode,
    name: name,
    price: 0,
    stock: stock,
  );
}
