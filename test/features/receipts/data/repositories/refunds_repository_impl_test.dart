import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/receipts/data/models/app_refund_model.dart';
import 'package:cashier_system/features/receipts/data/repositories/refunds_repository_impl.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';

void main() {
  late Box<AppRefundModel> box;
  late IRefundsRepository repository;

  setUpAll(() async {
    Hive.init('test/_hive_test');
    Hive.registerAdapter(AppRefundModelAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<AppRefundModel>('test_refunds_repo');
    repository = RefundsRepositoryImpl(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('test_refunds_repo');
  });

  final now = DateTime(2026, 7, 14, 10, 30, 0);

  RefundEntity makeRefund({
    String id = 'ref1',
    String originalReceiptId = 'r1',
    int amountRestored = 1000,
    RefundType type = RefundType.full,
  }) {
    return RefundEntity(
      id: id,
      originalReceiptId: originalReceiptId,
      refundDate: now,
      amountRestored: amountRestored,
      type: type,
    );
  }

  group('save', () {
    test('should persist refund and retrieve it', () async {
      final entity = makeRefund();

      final saveResult = await repository.save(entity);
      expect(saveResult, isA<Right<Failure, void>>());

      final result = await repository.getByOriginalReceipt('r1');
      final refunds = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(refunds.length, 1);
      expect(refunds[0].id, 'ref1');
      expect(refunds[0].amountRestored, 1000);
    });

    test('should overwrite existing refund with same id', () async {
      final first = makeRefund(id: 'ref1', originalReceiptId: 'r1', amountRestored: 500);
      final second = makeRefund(id: 'ref1', originalReceiptId: 'r1', amountRestored: 1000);

      await repository.save(first);
      await repository.save(second);

      final result = await repository.getByOriginalReceipt('r1');
      final refunds = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(refunds.length, 1);
      expect(refunds[0].amountRestored, 1000);
    });
  });

  group('getByOriginalReceipt', () {
    test('should return refunds for matching receipt', () async {
      await repository.save(makeRefund(id: 'ref1', originalReceiptId: 'r1'));
      await repository.save(makeRefund(id: 'ref2', originalReceiptId: 'r1'));
      await repository.save(makeRefund(id: 'ref3', originalReceiptId: 'r2'));

      final result = await repository.getByOriginalReceipt('r1');
      final refunds = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(refunds.length, 2);
      expect(refunds.every((r) => r.originalReceiptId == 'r1'), isTrue);
    });

    test('should return empty list for receipt with no refunds', () async {
      final result = await repository.getByOriginalReceipt('nonexistent');
      final refunds = result.fold(
        (failure) => throw failure,
        (list) => list,
      );

      expect(refunds, isEmpty);
    });
  });
}
