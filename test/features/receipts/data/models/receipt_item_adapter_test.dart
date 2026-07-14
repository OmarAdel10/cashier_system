import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/receipts/data/models/receipt_item_adapter.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';

void main() {
  group('ReceiptItemAdapter', () {
    late Box<ReceiptItem> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(ReceiptItemAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<ReceiptItem>('test_receipt_items');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_receipt_items');
    });

    test('should persist and retrieve ReceiptItem via Hive', () async {
      final item = const ReceiptItem(
        name: 'Pen',
        barcode: '123456789012',
        quantity: 3,
        unitPricePiastres: 500,
      );

      await box.put('item_1', item);
      final retrieved = box.get('item_1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Pen');
      expect(retrieved.barcode, '123456789012');
      expect(retrieved.quantity, 3);
      expect(retrieved.unitPricePiastres, 500);
    });

    test('should have typeId 6', () {
      expect(ReceiptItemAdapter().typeId, 6);
    });
  });
}
