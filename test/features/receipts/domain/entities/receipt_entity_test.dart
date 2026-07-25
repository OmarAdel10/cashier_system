import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';

void main() {
  group('ReceiptEntity', () {
    final now = DateTime.now();
    final item = ReceiptItem(
      name: 'Item 1',
      barcode: '123',
      quantity: 2,
      unitPricePiastres: 1000,
    );

    final receipt = ReceiptEntity(
      id: 'r1',
      shiftId: 's1',
      orderNumber: 'ORD-001',
      items: [item],
      subtotalPiastres: 2000,
      discountPiastres: 100,
      taxPiastres: 190,
      totalPiastres: 2090,
      createdAt: now,
      username: 'cashier1',
      stockUpdated: true,
      status: ReceiptStatus.active,
    );

    test('should create with default values', () {
      final r = ReceiptEntity(
        id: 'r2',
        shiftId: 's2',
        orderNumber: 'ORD-002',
        items: [item],
        subtotalPiastres: 1000,
        totalPiastres: 1000,
        createdAt: now,
        username: 'cashier2',
      );
      expect(r.discountPiastres, 0);
      expect(r.taxPiastres, 0);
      expect(r.stockUpdated, false);
      expect(r.status, ReceiptStatus.active);
    });

    test('copyWith should override fields', () {
      final modified = receipt.copyWith(
        id: 'r2',
        orderNumber: 'ORD-002',
        totalPiastres: 3000,
        status: ReceiptStatus.returned,
      );
      expect(modified.id, 'r2');
      expect(modified.orderNumber, 'ORD-002');
      expect(modified.totalPiastres, 3000);
      expect(modified.status, ReceiptStatus.returned);
      expect(modified.shiftId, receipt.shiftId);
      expect(modified.createdAt, receipt.createdAt);
    });

    test('copyWith clearStockUpdated should work', () {
      final modified = receipt.copyWith(clearStockUpdated: true);
      expect(modified.stockUpdated, false);
    });

    test('copyWith should preserve unset fields', () {
      final modified = receipt.copyWith(orderNumber: 'ORD-NEW');
      expect(modified.orderNumber, 'ORD-NEW');
      expect(modified.id, receipt.id);
      expect(modified.shiftId, receipt.shiftId);
      expect(modified.subtotalPiastres, receipt.subtotalPiastres);
      expect(modified.totalPiastres, receipt.totalPiastres);
      expect(modified.stockUpdated, receipt.stockUpdated);
      expect(modified.status, receipt.status);
    });

    test('equality should work', () {
      final same = ReceiptEntity(
        id: 'r1',
        shiftId: 's1',
        orderNumber: 'ORD-001',
        items: [item],
        subtotalPiastres: 2000,
        discountPiastres: 100,
        taxPiastres: 190,
        totalPiastres: 2090,
        createdAt: now,
        username: 'cashier1',
        stockUpdated: true,
        status: ReceiptStatus.active,
      );
      final different = ReceiptEntity(
        id: 'r2',
        shiftId: 's1',
        orderNumber: 'ORD-002',
        items: [item],
        subtotalPiastres: 1000,
        totalPiastres: 1000,
        createdAt: now,
        username: 'cashier2',
      );
      expect(same == receipt, isTrue);
      expect(same.hashCode, receipt.hashCode);
      expect(different == receipt, isFalse);
    });

    test('toString should return correct format', () {
      expect(
        receipt.toString(),
        'ReceiptEntity(id: r1, orderNumber: ORD-001, status: ReceiptStatus.active, stockUpdated: true, stockFailedBarcodes: [], modificationCount: 0)',
      );
    });
  });

  group('ReceiptItem', () {
    final item = ReceiptItem(
      name: 'Test Product',
      barcode: 'ABC123',
      quantity: 3,
      unitPricePiastres: 500,
    );

    test('totalPiastres should calculate correctly', () {
      expect(item.totalPiastres, 1500);
    });

    test('copyWith should work', () {
      final modified = item.copyWith(quantity: 5);
      expect(modified.quantity, 5);
      expect(modified.totalPiastres, 2500);
      expect(modified.name, item.name);
    });

    test('equality should work', () {
      final same = ReceiptItem(
        name: 'Test Product',
        barcode: 'ABC123',
        quantity: 3,
        unitPricePiastres: 500,
      );
      expect(same == item, isTrue);
      expect(same.hashCode, item.hashCode);
    });
  });
}
