import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_event.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';

void main() {
  group('SalesBloc', () {
    late FakeReceiptsRepository receiptsRepo;
    late SalesBloc bloc;

    setUp(() {
      receiptsRepo = FakeReceiptsRepository();
      bloc = SalesBloc(receiptsRepo: receiptsRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state has initial status', () {
      expect(bloc.state.status, SalesStatus.initial);
      expect(bloc.state.todaySummary, isNull);
      expect(bloc.state.monthData, isNull);
      expect(bloc.state.shiftReceipts, isNull);
      expect(bloc.state.failure, isNull);
    });

    group('LoadTodaySummary', () {
      test('computes summary from today receipts', () async {
        final today = DateTime.now();
        await receiptsRepo.save(ReceiptEntity(
          id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
          items: const [],
          subtotalPiastres: 10000, totalPiastres: 12000,
          createdAt: today, username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r2', shiftId: 's1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 5000, totalPiastres: 5500,
          createdAt: today, username: 'cashier1',
        ));

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.todaySummary != null &&
                s.todaySummary!.receiptCount == 2 &&
                s.todaySummary!.totalPiastres == 17500),
          ]),
        );
      });

      test('itemsSold sums quantities from all receipt items', () async {
        final today = DateTime.now();
        await receiptsRepo.save(ReceiptEntity(
          id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
          items: const [
            ReceiptItem(name: 'Pen', barcode: '111', quantity: 3, unitPricePiastres: 1000),
            ReceiptItem(name: 'Book', barcode: '222', quantity: 1, unitPricePiastres: 5000),
          ],
          subtotalPiastres: 8000, totalPiastres: 8000,
          createdAt: today, username: 'cashier1',
        ));

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.todaySummary!.itemsSold == 4),
          ]),
        );
      });

      test('omits non-today receipts from calculation', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
          items: const [],
          subtotalPiastres: 99999, totalPiastres: 99999,
          createdAt: yesterday, username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r2', shiftId: 's1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 5000, totalPiastres: 5500,
          createdAt: today, username: 'cashier1',
        ));

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.todaySummary!.receiptCount == 1 &&
                s.todaySummary!.totalPiastres == 5500),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(receiptsRepo: failingRepo);

        failingBloc.add(const LoadTodaySummary());

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.error && s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadMonth', () {
      test('loads receipts for given month and computes data', () async {
        await receiptsRepo.save(ReceiptEntity(
          id: 'r1', shiftId: 's1', orderNumber: 'ORD-001',
          items: const [],
          subtotalPiastres: 10000, totalPiastres: 12000,
          createdAt: DateTime(2026, 3, 5), username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r2', shiftId: 's1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 5000, totalPiastres: 5500,
          createdAt: DateTime(2026, 3, 15), username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r3', shiftId: 's1', orderNumber: 'ORD-003',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 0,
          createdAt: DateTime(2026, 4, 1), username: 'cashier1',
        ));

        bloc.add(const LoadMonth(year: 2026, month: 3));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.monthData != null &&
                s.monthData!.year == 2026 &&
                s.monthData!.month == 3 &&
                s.monthData!.receiptCount == 2 &&
                s.monthData!.totalPiastres == 17500),
          ]),
        );
      });

      test('clears previous monthData when loading', () async {
        bloc.add(const LoadMonth(year: 2026, month: 3));
        await bloc.stream.firstWhere((s) => s.status == SalesStatus.ready);

        bloc.add(const LoadMonth(year: 2026, month: 4));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) =>
                s.status == SalesStatus.loading &&
                s.monthData == null),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.monthData != null &&
                s.monthData!.month == 4),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(receiptsRepo: failingRepo);

        failingBloc.add(const LoadMonth(year: 2026, month: 1));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.error && s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadShiftReceipts', () {
      test('loads receipts for a shift sorted by date descending', () async {
        await receiptsRepo.save(ReceiptEntity(
          id: 'r1', shiftId: 'shift-1', orderNumber: 'ORD-001',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 1000,
          createdAt: DateTime(2026, 1, 1, 8, 0), username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r2', shiftId: 'shift-1', orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 2000,
          createdAt: DateTime(2026, 1, 1, 9, 0), username: 'cashier1',
        ));
        await receiptsRepo.save(ReceiptEntity(
          id: 'r3', shiftId: 'other', orderNumber: 'ORD-003',
          items: const [],
          subtotalPiastres: 0, totalPiastres: 3000,
          createdAt: DateTime(2026, 1, 1), username: 'cashier2',
        ));

        bloc.add(const LoadShiftReceipts(shiftId: 'shift-1'));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.ready &&
                s.shiftReceipts != null &&
                s.shiftReceipts!.length == 2 &&
                s.shiftReceipts![0].orderNumber == 'ORD-002' &&
                s.shiftReceipts![1].orderNumber == 'ORD-001'),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(receiptsRepo: failingRepo);

        failingBloc.add(const LoadShiftReceipts(shiftId: 'x'));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) =>
                s.status == SalesStatus.error && s.failure != null),
          ]),
        );

        failingBloc.close();
      });
    });
  });
}
