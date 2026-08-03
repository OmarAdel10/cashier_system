import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';

void main() {
  group('RefundLockFailure', () {
    test('should store receiptId, currentStatus, and message', () {
      const failure = RefundLockFailure('locked', receiptId: 'r1', currentStatus: ReceiptStatus.active);
      expect(failure.message, 'locked');
      expect(failure.receiptId, 'r1');
      expect(failure.currentStatus, ReceiptStatus.active);
    });

    test('should support equality', () {
      const a = RefundLockFailure('locked', receiptId: 'r1', currentStatus: ReceiptStatus.active);
      const b = RefundLockFailure('locked', receiptId: 'r1', currentStatus: ReceiptStatus.active);
      expect(a, equals(b));
    });

    test('should detect inequality', () {
      const a = RefundLockFailure('locked', receiptId: 'r1', currentStatus: ReceiptStatus.active);
      const b = RefundLockFailure('locked', receiptId: 'r2', currentStatus: ReceiptStatus.returned);
      expect(a, isNot(equals(b)));
    });

    test('toString should include type and fields', () {
      const failure = RefundLockFailure('locked', receiptId: 'r1', currentStatus: ReceiptStatus.active);
      expect(failure.toString(), contains('RefundLockFailure'));
      expect(failure.toString(), contains('r1'));
      expect(failure.toString(), contains('active'));
    });
  });
}
