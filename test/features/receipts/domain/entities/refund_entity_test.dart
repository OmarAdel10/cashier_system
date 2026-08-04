import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';

void main() {
  group('RefundType', () {
    test('should have full and partial values', () {
      expect(RefundType.full, RefundType.full);
      expect(RefundType.partial, RefundType.partial);
    });
  });

  group('RefundEntity', () {
    final now = DateTime.now();
    final refund = RefundEntity(
      id: 'ref1',
      originalReceiptId: 'rec1',
      refundDate: now,
      amountRestored: 5000,
      type: RefundType.full,
    );

    test('should create with correct values', () {
      expect(refund.id, 'ref1');
      expect(refund.originalReceiptId, 'rec1');
      expect(refund.refundDate, now);
      expect(refund.amountRestored, 5000);
      expect(refund.type, RefundType.full);
    });

    test('copyWith should override fields', () {
      final modified = refund.copyWith(amountRestored: 3000, type: RefundType.partial);
      expect(modified.amountRestored, 3000);
      expect(modified.type, RefundType.partial);
      expect(modified.id, refund.id);
    });

    test('equality should work', () {
      final same = RefundEntity(
        id: 'ref1',
        originalReceiptId: 'rec1',
        refundDate: now,
        amountRestored: 5000,
        type: RefundType.full,
      );
      final different = RefundEntity(
        id: 'ref2',
        originalReceiptId: 'rec1',
        refundDate: now,
        amountRestored: 2000,
        type: RefundType.partial,
      );
      expect(same == refund, isTrue);
      expect(same.hashCode, refund.hashCode);
      expect(different == refund, isFalse);
    });

    test('toString should return correct format', () {
      expect(
        refund.toString(),
        'RefundEntity(id: ref1, originalReceiptId: rec1, amountRestored: 5000, type: RefundType.full)',
      );
    });
  });
}
