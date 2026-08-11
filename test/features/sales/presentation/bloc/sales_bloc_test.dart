import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_event.dart';
import 'package:cashier_system/features/sales/presentation/bloc/sales_state.dart';
import '../../helpers/fake_shifts_repository.dart';
import '../../../checkout/helpers/fake_session_record_repository.dart';
import '../../../inventory/helpers/fake_inventory_repository.dart';
import '../../../receipts/helpers/fake_receipts_repository.dart';

void main() {
  group('SalesBloc', () {
    late FakeReceiptsRepository receiptsRepo;
    late FakeShiftsRepository shiftsRepo;
    late FakeSessionRecordRepository sessionRecordsRepo;
    late SalesBloc bloc;

    setUp(() {
      receiptsRepo = FakeReceiptsRepository();
      shiftsRepo = FakeShiftsRepository();
      sessionRecordsRepo = FakeSessionRecordRepository();
      bloc = SalesBloc(
        receiptsRepo: receiptsRepo,
        shiftsRepo: shiftsRepo,
        sessionRecordsRepo: sessionRecordsRepo,
      );
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
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 10000,
            totalPiastres: 12000,
            createdAt: today,
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 5000,
            totalPiastres: 5500,
            createdAt: today,
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.todaySummary != null &&
                  s.todaySummary!.receiptCount == 2 &&
                  s.todaySummary!.totalPiastres == 17500,
            ),
          ]),
        );
      });

      test('itemsSold sums quantities from all receipt items', () async {
        final today = DateTime.now();
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 3,
                unitPricePiastres: 1000,
              ),
              ReceiptItem(
                name: 'Book',
                barcode: '222',
                quantity: 1,
                unitPricePiastres: 5000,
              ),
            ],
            subtotalPiastres: 8000,
            totalPiastres: 8000,
            createdAt: today,
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.todaySummary!.itemsSold == 4,
            ),
          ]),
        );
      });

      test('omits non-today receipts from calculation', () async {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 99999,
            totalPiastres: 99999,
            createdAt: yesterday,
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 5000,
            totalPiastres: 5500,
            createdAt: today,
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.todaySummary!.receiptCount == 1 &&
                  s.todaySummary!.totalPiastres == 5500,
            ),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(
          receiptsRepo: failingRepo,
          shiftsRepo: FakeShiftsRepository(),
        );

        failingBloc.add(const LoadTodaySummary());

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.status == SalesStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadMonth', () {
      test('loads receipts for given month and builds grouped data', () async {
        final shift = ShiftEntity(
          id: 's1',
          username: 'cashier1',
          startedAt: DateTime(2026, 3, 5, 9, 0),
          endedAt: DateTime(2026, 3, 5, 17, 0),
        );
        shiftsRepo.addShift(shift);

        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 10000,
            totalPiastres: 12000,
            createdAt: DateTime(2026, 3, 5, 10, 30),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 5000,
            totalPiastres: 5500,
            createdAt: DateTime(2026, 3, 5, 14, 0),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 3));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.monthData != null &&
                  s.monthData!.year == 2026 &&
                  s.monthData!.month == 3 &&
                  s.monthData!.receiptCount == 2 &&
                  s.monthData!.totalPiastres == 17500 &&
                  s.monthData!.days.length == 1 &&
                  s.monthData!.days[0].cashiers.length == 1 &&
                  s.monthData!.days[0].cashiers[0].shifts.length == 1 &&
                  s.monthData!.days[0].cashiers[0].shifts[0].receipts.length ==
                      2 &&
                  s.months.length == 1,
            ),
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
            predicate<SalesState>(
              (s) => s.status == SalesStatus.loading && s.monthData == null,
            ),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.monthData != null &&
                  s.monthData!.month == 4,
            ),
          ]),
        );
      });

      test('accumulates months in list', () async {
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: DateTime(2026, 1, 5),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 2000,
            totalPiastres: 2000,
            createdAt: DateTime(2026, 2, 10),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 1));
        await bloc.stream.firstWhere((s) => s.status == SalesStatus.ready);

        bloc.add(const LoadMonth(year: 2026, month: 2));
        await bloc.stream.firstWhere((s) => s.status == SalesStatus.ready);

        expect(bloc.state.months.length, equals(2));
        expect(bloc.state.months[0].month, equals(2));
        expect(bloc.state.months[1].month, equals(1));
      });

      test('replaces existing month in list', () async {
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: DateTime(2026, 1, 5),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 1));
        await bloc.stream.firstWhere((s) => s.status == SalesStatus.ready);
        final firstReceiptCount = bloc.state.monthData!.receiptCount;

        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 2000,
            totalPiastres: 2000,
            createdAt: DateTime(2026, 1, 15),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 1));
        await bloc.stream.firstWhere((s) => s.status == SalesStatus.ready);

        expect(bloc.state.months.length, equals(1));
        expect(
          bloc.state.months[0].receiptCount,
          greaterThan(firstReceiptCount),
        );
      });

      test('groups multiple days and cashiers', () async {
        shiftsRepo.addShift(
          ShiftEntity(
            id: 's1',
            username: 'cashier1',
            startedAt: DateTime(2026, 3, 5, 9, 0),
            endedAt: DateTime(2026, 3, 5, 17, 0),
          ),
        );
        shiftsRepo.addShift(
          ShiftEntity(
            id: 's2',
            username: 'cashier2',
            startedAt: DateTime(2026, 3, 6, 9, 0),
            endedAt: DateTime(2026, 3, 6, 17, 0),
          ),
        );

        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: DateTime(2026, 3, 5),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's2',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 2000,
            totalPiastres: 2000,
            createdAt: DateTime(2026, 3, 6),
            username: 'cashier2',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 3));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.monthData!.days.length == 2 &&
                  s.monthData!.days[0].cashiers[0].shifts[0].shiftId == 's2' &&
                  s.monthData!.days[1].cashiers[0].shifts[0].shiftId == 's1',
            ),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(
          receiptsRepo: failingRepo,
          shiftsRepo: FakeShiftsRepository(),
        );

        failingBloc.add(const LoadMonth(year: 2026, month: 1));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.status == SalesStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadShiftReceipts', () {
      test('loads receipts for a shift sorted by date descending', () async {
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 'shift-1',
            orderNumber: 'ORD-001',
            items: const [],
            subtotalPiastres: 0,
            totalPiastres: 1000,
            createdAt: DateTime(2026, 1, 1, 8, 0),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 'shift-1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 0,
            totalPiastres: 2000,
            createdAt: DateTime(2026, 1, 1, 9, 0),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r3',
            shiftId: 'other',
            orderNumber: 'ORD-003',
            items: const [],
            subtotalPiastres: 0,
            totalPiastres: 3000,
            createdAt: DateTime(2026, 1, 1),
            username: 'cashier2',
          ),
        );

        bloc.add(const LoadShiftReceipts(shiftId: 'shift-1'));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.shiftReceipts != null &&
                  s.shiftReceipts!.length == 2 &&
                  s.shiftReceipts![0].orderNumber == 'ORD-002' &&
                  s.shiftReceipts![1].orderNumber == 'ORD-001',
            ),
          ]),
        );
      });

      test('emits error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = SalesBloc(
          receiptsRepo: failingRepo,
          shiftsRepo: FakeShiftsRepository(),
        );

        failingBloc.add(const LoadShiftReceipts(shiftId: 'x'));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.status == SalesStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadSessionRecords', () {
      test('loads and sorts session records newest first', () async {
        final older = DateTime(2026, 8, 1, 10);
        final newer = DateTime(2026, 8, 1, 12);
        await sessionRecordsRepo.saveSessionRecord(
          SessionRecordEntity(
            id: 's1',
            shiftId: '',
            stationId: 'PS-1',
            stationName: 'PS4-1',
            parentCategory: 'PS4',
            tier: SessionTier.normal,
            startTime: older,
            endTime: older.add(const Duration(minutes: 60)),
            durationMinutes: 60,
            totalPiastres: 5000,
          ),
        );
        await sessionRecordsRepo.saveSessionRecord(
          SessionRecordEntity(
            id: 's2',
            shiftId: '',
            stationId: 'PS-1',
            stationName: 'PS4-1',
            parentCategory: 'PS4',
            tier: SessionTier.multi,
            startTime: newer,
            endTime: newer.add(const Duration(minutes: 90)),
            durationMinutes: 90,
            totalPiastres: 9000,
          ),
        );

        bloc.add(const LoadSessionRecords());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.sessionRecords != null &&
                  s.sessionRecords!.length == 2 &&
                  s.sessionRecords!.first.id == 's2' &&
                  s.sessionRecords!.first.tier == SessionTier.multi,
            ),
          ]),
        );
      });

      test('respects limit', () async {
        for (var i = 1; i <= 5; i++) {
          await sessionRecordsRepo.saveSessionRecord(
            SessionRecordEntity(
              id: 's$i',
              shiftId: '',
              stationId: 'PS-1',
              stationName: 'PS4-1',
              parentCategory: 'PS4',
              tier: SessionTier.normal,
              startTime: DateTime(2026, 1, i, 10),
              endTime: DateTime(2026, 1, i, 11),
              totalPiastres: 100 * i,
            ),
          );
        }

        bloc.add(const LoadSessionRecords(limit: 2));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.sessionRecords?.length == 2 &&
                  s.sessionRecords!.first.id == 's5',
            ),
          ]),
        );
      });

      test('emits error when repository fails', () async {
        sessionRecordsRepo.failOnGet = true;

        bloc.add(const LoadSessionRecords());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.status == SalesStatus.error && s.failure != null,
            ),
          ]),
        );
      });
    });

    group('profit', () {
      late FakeInventoryRepository inventoryRepo;

      setUp(() {
        inventoryRepo = FakeInventoryRepository();
        bloc = SalesBloc(
          receiptsRepo: receiptsRepo,
          shiftsRepo: shiftsRepo,
          sessionRecordsRepo: sessionRecordsRepo,
          inventoryRepo: inventoryRepo,
        );
      });

      test('computes today profit with costs when tax included', () async {
        await inventoryRepo.saveProduct(
          const ProductEntity(
            barcode: '111',
            name: 'Pen',
            price: 10.0,
            purchasePrice: 3.0,
          ),
        );
        final today = DateTime.now();
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 2000,
            taxPiastres: 500,
            totalPiastres: 2500,
            createdAt: today,
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.todaySummary!.profitPiastres == 1900,
            ),
          ]),
        );
      });

      test(
        'excludes tax from profit when includeTaxInProfit is false',
        () async {
          await inventoryRepo.saveProduct(
            const ProductEntity(
              barcode: '111',
              name: 'Pen',
              price: 10.0,
              purchasePrice: 3.0,
            ),
          );
          final today = DateTime.now();
          await receiptsRepo.save(
            ReceiptEntity(
              id: 'r1',
              shiftId: 's1',
              orderNumber: 'ORD-001',
              items: const [
                ReceiptItem(
                  name: 'Pen',
                  barcode: '111',
                  quantity: 2,
                  unitPricePiastres: 1000,
                ),
              ],
              subtotalPiastres: 2000,
              taxPiastres: 500,
              totalPiastres: 2500,
              createdAt: today,
              username: 'cashier1',
            ),
          );

          bloc.add(const LoadTodaySummary(includeTaxInProfit: false));

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<SalesState>((s) => s.status == SalesStatus.loading),
              predicate<SalesState>(
                (s) => s.todaySummary!.profitPiastres == 1400,
              ),
            ]),
          );
        },
      );

      test('treats unknown product cost as zero', () async {
        final today = DateTime.now();
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Ghost',
                barcode: '999',
                quantity: 1,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: today,
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadTodaySummary());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) => s.todaySummary!.profitPiastres == 1000,
            ),
          ]),
        );
      });

      test('computes month profit with costs', () async {
        await inventoryRepo.saveProduct(
          const ProductEntity(
            barcode: '111',
            name: 'Pen',
            price: 10.0,
            purchasePrice: 3.0,
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 2000,
            taxPiastres: 500,
            totalPiastres: 2500,
            createdAt: DateTime(2026, 3, 5, 10, 30),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 3));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>((s) => s.monthData!.profitPiastres == 1900),
          ]),
        );
      });

      test('excludes returned receipts from month totals but keeps them in '
          'day lists', () async {
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 2000,
            totalPiastres: 2500,
            status: ReceiptStatus.returned,
            createdAt: DateTime(2026, 3, 5, 10, 30),
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 1,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: DateTime(2026, 3, 6, 14, 0),
            username: 'cashier1',
          ),
        );

        bloc.add(const LoadMonth(year: 2026, month: 3));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<SalesState>((s) => s.status == SalesStatus.loading),
            predicate<SalesState>(
              (s) =>
                  s.status == SalesStatus.ready &&
                  s.monthData!.receiptCount == 1 &&
                  s.monthData!.totalPiastres == 1000 &&
                  s.monthData!.itemsSold == 1 &&
                  s.monthData!.profitPiastres == 1000 &&
                  s.monthData!.days.length == 2 &&
                  s.monthData!.days.any(
                    (d) => d.cashiers.any(
                      (c) => c.shifts.any(
                        (sh) => sh.receipts.any((r) => r.id == 'r1'),
                      ),
                    ),
                  ),
            ),
          ]),
        );
      });
    });
  });
}
