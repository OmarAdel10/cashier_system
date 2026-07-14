import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/receipts/data/models/app_receipt_model.dart';
import 'package:cashier_system/features/receipts/data/models/receipt_item_adapter.dart';
import 'package:cashier_system/features/receipts/data/repositories/receipts_repository_impl.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';

void main() {
  late Box<AppReceiptModel> box;
  late IReceiptsRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppReceiptModelAdapter());
    Hive.registerAdapter(ReceiptItemAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppReceiptModel>('test_receipts_repo');
    repository = ReceiptsRepositoryImpl(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_receipts_repo');
  });

  ReceiptEntity makeReceipt({
    String id = 'r1',
    String shiftId = 's1',
    String orderNumber = 'ORD-00001',
    int subtotal = 1000,
    int total = 1000,
    DateTime? createdAt,
    String username = 'cashier1',
  }) {
    return ReceiptEntity(
      id: id,
      shiftId: shiftId,
      orderNumber: orderNumber,
      items: const [
        ReceiptItem(name: 'Pen', barcode: '123', quantity: 2, unitPricePiastres: 500),
      ],
      subtotalPiastres: subtotal,
      totalPiastres: total,
      createdAt: createdAt ?? DateTime(2026, 7, 14, 10, 0, 0),
      username: username,
    );
  }

  group('save', () {
    test('should persist receipt and retrieve it via getAll', () async {
      final entity = makeReceipt();

      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getAll();
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 1);
      expect(receipts[0].id, 'r1');
      expect(receipts[0].orderNumber, 'ORD-00001');
      expect(receipts[0].items.length, 1);
    });

    test('should overwrite existing receipt with same id', () async {
      final first = makeReceipt(orderNumber: 'ORD-00001');
      final second = makeReceipt(id: 'r1', orderNumber: 'ORD-00002');

      await repository.save(first);
      await repository.save(second);

      final result = await repository.getAll();
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 1);
      expect(receipts[0].orderNumber, 'ORD-00002');
    });
  });

  group('getAll', () {
    test('should return empty list when box is empty', () async {
      final result = await repository.getAll();
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts, isEmpty);
    });

    test('should return all stored receipts', () async {
      await repository.save(makeReceipt(id: 'r1'));
      await repository.save(makeReceipt(id: 'r2', orderNumber: 'ORD-00002'));

      final result = await repository.getAll();
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 2);
    });
  });

  group('getByShift', () {
    test('should return receipts for matching shift', () async {
      await repository.save(makeReceipt(id: 'r1', shiftId: 'shift-a'));
      await repository.save(makeReceipt(id: 'r2', shiftId: 'shift-b'));
      await repository.save(makeReceipt(id: 'r3', shiftId: 'shift-a'));

      final result = await repository.getByShift('shift-a');
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 2);
      expect(receipts.every((r) => r.shiftId == 'shift-a'), isTrue);
    });

    test('should return empty list for unknown shift', () async {
      await repository.save(makeReceipt(id: 'r1', shiftId: 'shift-a'));

      final result = await repository.getByShift('nonexistent');
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts, isEmpty);
    });
  });

  group('getByMonth', () {
    test('should return receipts for matching month', () async {
      await repository.save(makeReceipt(
        id: 'r1',
        createdAt: DateTime(2026, 7, 1),
      ));
      await repository.save(makeReceipt(
        id: 'r2',
        createdAt: DateTime(2026, 7, 15),
      ));
      await repository.save(makeReceipt(
        id: 'r3',
        createdAt: DateTime(2026, 8, 1),
      ));

      final result = await repository.getByMonth(2026, 7);
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 2);
    });

    test('should return empty list for month with no receipts', () async {
      final result = await repository.getByMonth(2025, 1);
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts, isEmpty);
    });
  });

  group('getByDate', () {
    test('should return receipts for matching date', () async {
      await repository.save(makeReceipt(
        id: 'r1',
        createdAt: DateTime(2026, 7, 14, 10, 0),
      ));
      await repository.save(makeReceipt(
        id: 'r2',
        createdAt: DateTime(2026, 7, 14, 15, 0),
      ));
      await repository.save(makeReceipt(
        id: 'r3',
        createdAt: DateTime(2026, 7, 13, 10, 0),
      ));

      final result = await repository.getByDate(DateTime(2026, 7, 14));
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts.length, 2);
    });

    test('should return empty list for date with no receipts', () async {
      final result = await repository.getByDate(DateTime(2025, 1, 1));
      final receipts = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(receipts, isEmpty);
    });
  });
}
