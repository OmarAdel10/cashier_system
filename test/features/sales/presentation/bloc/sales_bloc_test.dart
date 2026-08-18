import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/exports/csv_writer.dart';
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
import '../../../expenses/helpers/fake_expenses_repository.dart';
import 'package:cashier_system/features/expenses/domain/entities/expense_entity.dart';
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

    group('Expense sums', () {
      test('LoadTodaySummary includes today expenses sum', () async {
        final expensesRepo = FakeExpensesRepository();
        await expensesRepo.save(
          ExpenseEntity(
            id: 'e1',
            shiftId: 's1',
            username: 'cashier1',
            lines: [
              ExpenseLineEntity(
                barcode: '111',
                name: 'Bread',
                quantity: 2,
                costPiastres: 1500,
              ),
            ],
            createdAt: DateTime.now(),
          ),
        );
        final bloc = SalesBloc(
          receiptsRepo: FakeReceiptsRepository(),
          shiftsRepo: FakeShiftsRepository(),
          expensesRepo: expensesRepo,
        );
        bloc.add(LoadTodaySummary());
        final state = await bloc.stream.firstWhere(
          (s) => s.status == SalesStatus.ready,
        );
        expect(state.todayExpensesPiastres, 3000);
        await bloc.close();
      });

      test('LoadShiftReceipts includes shift expenses sum', () async {
        final expensesRepo = FakeExpensesRepository();
        await expensesRepo.save(
          ExpenseEntity(
            id: 'e1',
            shiftId: 's1',
            username: 'cashier1',
            lines: const [
              ExpenseLineEntity(
                barcode: '111',
                name: 'Bread',
                quantity: 1,
                costPiastres: 5000,
              ),
            ],
            createdAt: DateTime.now(),
          ),
        );
        final bloc = SalesBloc(
          receiptsRepo: FakeReceiptsRepository(),
          shiftsRepo: FakeShiftsRepository(),
          expensesRepo: expensesRepo,
        );
        bloc.add(LoadShiftReceipts(shiftId: 's1'));
        final state = await bloc.stream.firstWhere(
          (s) => s.status == SalesStatus.ready,
        );
        expect(state.shiftExpensesPiastres, 5000);
        await bloc.close();
      });

      test(
        'LoadMonth includes monthly expenses sum and day expense totals',
        () async {
          final receiptsRepo = FakeReceiptsRepository();
          await receiptsRepo.save(
            ReceiptEntity(
              id: 'r1',
              shiftId: 's1',
              orderNumber: 'ORD-001',
              items: const [],
              subtotalPiastres: 0,
              taxPiastres: 0,
              totalPiastres: 0,
              createdAt: DateTime(2026, 8, 11),
              username: 'cashier1',
            ),
          );
          final expensesRepo = FakeExpensesRepository();
          await expensesRepo.save(
            ExpenseEntity(
              id: 'e1',
              shiftId: 's1',
              username: 'cashier1',
              lines: [
                ExpenseLineEntity(
                  barcode: '111',
                  name: 'Bread',
                  quantity: 2,
                  costPiastres: 1500,
                ),
              ],
              createdAt: DateTime(2026, 8, 11),
            ),
          );
          final bloc = SalesBloc(
            receiptsRepo: receiptsRepo,
            shiftsRepo: FakeShiftsRepository(),
            expensesRepo: expensesRepo,
          );
          bloc.add(const LoadMonth(year: 2026, month: 8));
          final state = await bloc.stream.firstWhere(
            (s) => s.status == SalesStatus.ready,
          );
          expect(state.monthlyExpensesPiastres, 3000);
          expect(
            state.monthData?.days.any((d) => d.expensesPiastres == 3000),
            isTrue,
          );
          await bloc.close();
        },
      );

      test('LoadShiftReceipts merges expenses as synthetic expense receipts '
          'sorted by date', () async {
        final receiptsRepo = FakeReceiptsRepository();
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
        final expensesRepo = FakeExpensesRepository();
        await expensesRepo.save(
          ExpenseEntity(
            id: 'e1',
            shiftId: 'shift-1',
            username: 'cashier1',
            name: 'Bread run',
            lines: [
              ExpenseLineEntity(
                barcode: '111',
                name: 'Bread',
                quantity: 2,
                costPiastres: 1500,
              ),
            ],
            createdAt: DateTime(2026, 1, 1, 9, 30),
          ),
        );
        final bloc = SalesBloc(
          receiptsRepo: receiptsRepo,
          shiftsRepo: FakeShiftsRepository(),
          expensesRepo: expensesRepo,
        );
        bloc.add(const LoadShiftReceipts(shiftId: 'shift-1'));
        final state = await bloc.stream.firstWhere(
          (s) => s.status == SalesStatus.ready,
        );
        expect(state.shiftReceipts, isNotNull);
        expect(state.shiftReceipts!.length, 2);
        expect(state.shiftReceipts![0].status, ReceiptStatus.expense);
        expect(state.shiftReceipts![0].orderNumber, 'Bread run');
        expect(state.shiftReceipts![0].id, 'e1');
        expect(state.shiftReceipts![0].items.length, 1);
        expect(state.shiftReceipts![0].items.first.barcode, '111');
        expect(state.shiftReceipts![0].items.first.name, 'Bread');
        expect(state.shiftReceipts![0].items.first.quantity, 2);
        expect(state.shiftReceipts![0].items.first.unitPricePiastres, 1500);
        expect(state.shiftReceipts![0].totalPiastres, 3000);
        expect(state.shiftReceipts![1].orderNumber, 'ORD-001');
        expect(state.shiftExpensesPiastres, 3000);
        await bloc.close();
      });

      test('falls back to short id order number for unnamed legacy '
          'expenses', () async {
        final expensesRepo = FakeExpensesRepository();
        await expensesRepo.save(
          ExpenseEntity(
            id: 'a1b2c3d4-e5f6-uuid',
            shiftId: 'shift-1',
            username: 'cashier1',
            lines: [
              ExpenseLineEntity(
                barcode: '111',
                name: 'Bread',
                quantity: 1,
                costPiastres: 1000,
              ),
            ],
            createdAt: DateTime(2026, 1, 1, 9, 30),
          ),
        );
        final bloc = SalesBloc(
          receiptsRepo: FakeReceiptsRepository(),
          shiftsRepo: FakeShiftsRepository(),
          expensesRepo: expensesRepo,
        );
        bloc.add(const LoadShiftReceipts(shiftId: 'shift-1'));
        final state = await bloc.stream.firstWhere(
          (s) => s.status == SalesStatus.ready,
        );
        expect(state.shiftReceipts!.single.orderNumber, 'EXP-A1B2C');
        await bloc.close();
      });

      test('LoadMonth merges expenses into day groups and tracks '
          'expenseCount', () async {
        final receiptsRepo = FakeReceiptsRepository();
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
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
            createdAt: DateTime(2026, 3, 5, 10, 30),
            username: 'cashier1',
          ),
        );
        final expensesRepo = FakeExpensesRepository();
        await expensesRepo.save(
          ExpenseEntity(
            id: 'e1',
            shiftId: 's1',
            username: 'cashier1',
            lines: [
              ExpenseLineEntity(
                barcode: '222',
                name: 'Water',
                quantity: 3,
                costPiastres: 500,
              ),
            ],
            createdAt: DateTime(2026, 3, 5, 11, 0),
          ),
        );
        final bloc = SalesBloc(
          receiptsRepo: receiptsRepo,
          shiftsRepo: FakeShiftsRepository(),
          expensesRepo: expensesRepo,
        );
        bloc.add(const LoadMonth(year: 2026, month: 3));
        final state = await bloc.stream.firstWhere(
          (s) => s.status == SalesStatus.ready,
        );
        expect(state.monthData, isNotNull);
        expect(state.monthData!.expenseCount, 1);
        expect(state.monthlyExpensesPiastres, 1500);
        expect(state.monthData!.receiptCount, 1);
        expect(state.monthData!.totalPiastres, 1000);
        expect(state.monthData!.itemsSold, 1);
        final dayReceipts = state.monthData!.days
            .expand((d) => d.cashiers)
            .expand((c) => c.shifts)
            .expand((sh) => sh.receipts)
            .toList();
        expect(dayReceipts.length, 2);
        expect(
          dayReceipts.where((r) => r.status == ReceiptStatus.expense).length,
          1,
        );
        final expense = dayReceipts.firstWhere(
          (r) => r.status == ReceiptStatus.expense,
        );
        expect(expense.id, 'e1');
        expect(expense.orderNumber, 'EXP-E1');
        expect(expense.items.first.name, 'Water');
        expect(
          state.monthData!.days.first.expensesPiastres,
          1500,
        );
        expect(state.months.single.expenseCount, 1);
        await bloc.close();
      });
    });

    group('exports', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('sales_export_test');
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      Future<void> seedReceipts() async {
        final date = DateTime(2026, 8, 15);
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r-multi',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pepsi',
                barcode: '1',
                quantity: 2,
                unitPricePiastres: 500,
              ),
              ReceiptItem(
                name: 'Water',
                barcode: '2',
                quantity: 1,
                unitPricePiastres: 500,
              ),
            ],
            subtotalPiastres: 1500,
            totalPiastres: 1500,
            createdAt: date,
            username: 'cashier1',
          ),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r-single',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [
              ReceiptItem(
                name: 'Cola',
                barcode: '3',
                quantity: 1,
                unitPricePiastres: 1000,
              ),
            ],
            subtotalPiastres: 1000,
            totalPiastres: 1000,
            createdAt: date,
            username: 'cashier1',
          ),
        );
      }

      Future<SalesState> waitForExport() async {
        return bloc.stream
            .firstWhere((s) => s.exportProgress == ExportStatus.success)
            .timeout(const Duration(seconds: 10));
      }

      test('writes one row per item to a CSV file', () async {
        await seedReceipts();
        bloc.add(
          ExportByMonth(
            year: 2026,
            month: 8,
            format: 'csv',
            exportDirectoryPath: tempDir.path,
          ),
        );

        await waitForExport();

        final path = '${tempDir.path}/sales_month_2026_08.csv';
        final bytes = await File(path).readAsBytes();
        expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);

        final rows = await readCsvRows(path);
        final multiRows = rows.where((r) => r[2] == 'ORD-001').toList();
        expect(multiRows, hasLength(2));
        expect(multiRows[0][3], 'Pepsi');
        expect(multiRows[0][4], '2');
        expect(multiRows[0][5], '5.00');
        expect(multiRows[0][6], '10.00');
        expect(multiRows[1][3], 'Water');
        expect(multiRows[1][6], '5.00');

        final singleRows = rows.where((r) => r[2] == 'ORD-002').toList();
        expect(singleRows, hasLength(1));
        expect(singleRows.single[3], 'Cola');
        expect(singleRows.single[5], '10.00');
        expect(singleRows.single[6], '10.00');
      });
    });
  });
}
