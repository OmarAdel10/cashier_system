import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/receipts/data/models/app_receipt_model.dart';
import 'package:cashier_system/features/receipts/data/models/receipt_item_adapter.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';

void main() {
  final now = DateTime(2026, 7, 14, 10, 30, 0);
  final items = [
    const ReceiptItem(
      name: 'Pen',
      barcode: '123',
      quantity: 2,
      unitPricePiastres: 500,
    ),
    const ReceiptItem(
      name: 'Notebook',
      barcode: '456',
      quantity: 1,
      unitPricePiastres: 1500,
    ),
  ];

  group('AppReceiptModel', () {
    group('fromJson', () {
      test('should return a valid model with all fields', () {
        final json = {
          'id': 'receipt-1',
          'shiftId': 'shift-1',
          'orderNumber': 'ORD-00001',
          'items': [
            {
              'name': 'Pen',
              'barcode': '123',
              'quantity': 2,
              'unitPricePiastres': 500,
            },
            {
              'name': 'Notebook',
              'barcode': '456',
              'quantity': 1,
              'unitPricePiastres': 1500,
            },
          ],
          'subtotalPiastres': 2500,
          'discountPiastres': 250,
          'taxPiastres': 225,
          'totalPiastres': 2475,
          'createdAt': now.toIso8601String(),
          'username': 'cashier1',
          'stockUpdated': true,
          'status': 0,
        };

        final model = AppReceiptModel.fromJson(json);

        expect(model.id, 'receipt-1');
        expect(model.shiftId, 'shift-1');
        expect(model.orderNumber, 'ORD-00001');
        expect(model.items.length, 2);
        expect(model.items[0].name, 'Pen');
        expect(model.items[1].name, 'Notebook');
        expect(model.subtotalPiastres, 2500);
        expect(model.discountPiastres, 250);
        expect(model.taxPiastres, 225);
        expect(model.totalPiastres, 2475);
        expect(model.createdAt, now);
        expect(model.username, 'cashier1');
        expect(model.stockUpdated, true);
        expect(model.status, ReceiptStatus.active);
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final model = AppReceiptModel.fromJson(json);

        expect(model.id, '');
        expect(model.shiftId, '');
        expect(model.orderNumber, '');
        expect(model.items, isEmpty);
        expect(model.subtotalPiastres, 0);
        expect(model.discountPiastres, 0);
        expect(model.taxPiastres, 0);
        expect(model.totalPiastres, 0);
        expect(model.createdAt, isA<DateTime>());
        expect(model.username, '');
        expect(model.stockUpdated, false);
        expect(model.status, ReceiptStatus.active);
      });
    });

    group('toJson', () {
      test('should return a valid JSON map', () {
        final model = AppReceiptModel(
          id: 'receipt-1',
          shiftId: 'shift-1',
          orderNumber: 'ORD-00001',
          items: items,
          subtotalPiastres: 2500,
          discountPiastres: 250,
          taxPiastres: 225,
          totalPiastres: 2475,
          createdAt: now,
          username: 'cashier1',
          stockUpdated: true,
          status: ReceiptStatus.active,
        );

        final json = model.toJson();

        expect(json['id'], 'receipt-1');
        expect(json['shiftId'], 'shift-1');
        expect(json['orderNumber'], 'ORD-00001');
        expect(json['items'], isA<List>());
        expect((json['items'] as List).length, 2);
        expect(json['subtotalPiastres'], 2500);
        expect(json['discountPiastres'], 250);
        expect(json['taxPiastres'], 225);
        expect(json['totalPiastres'], 2475);
        expect(json['createdAt'], now.toIso8601String());
        expect(json['username'], 'cashier1');
        expect(json['stockUpdated'], true);
        expect(json['status'], 0);
      });
    });

    group('round-trip', () {
      test('should serialize and deserialize correctly', () {
        final original = AppReceiptModel(
          id: 'rt-1',
          shiftId: 'shift-2',
          orderNumber: 'ORD-00002',
          items: items,
          subtotalPiastres: 2000,
          discountPiastres: 0,
          taxPiastres: 0,
          totalPiastres: 2000,
          createdAt: now,
          username: 'cashier2',
          stockUpdated: false,
          status: ReceiptStatus.active,
        );

        final json = original.toJson();
        final decoded = AppReceiptModel.fromJson(json);

        expect(decoded.id, original.id);
        expect(decoded.shiftId, original.shiftId);
        expect(decoded.orderNumber, original.orderNumber);
        expect(decoded.items.length, original.items.length);
        expect(decoded.items[0].name, original.items[0].name);
        expect(decoded.subtotalPiastres, original.subtotalPiastres);
        expect(decoded.discountPiastres, original.discountPiastres);
        expect(decoded.taxPiastres, original.taxPiastres);
        expect(decoded.totalPiastres, original.totalPiastres);
        expect(decoded.createdAt, original.createdAt);
        expect(decoded.username, original.username);
        expect(decoded.stockUpdated, original.stockUpdated);
        expect(decoded.status, original.status);
      });
    });

    group('identity', () {
      test('should be a ReceiptEntity', () {
        final model = AppReceiptModel(
          id: 'r1',
          shiftId: 's1',
          orderNumber: 'ORD-1',
          items: [],
          subtotalPiastres: 0,
          totalPiastres: 0,
          createdAt: now,
          username: 'u1',
        );
        expect(model, isA<ReceiptEntity>());
      });
    });

    group('toEntity', () {
      test('should convert to ReceiptEntity preserving all fields', () {
        final model = AppReceiptModel(
          id: 'r1',
          shiftId: 's1',
          orderNumber: 'ORD-1',
          items: items,
          subtotalPiastres: 2500,
          discountPiastres: 250,
          taxPiastres: 225,
          totalPiastres: 2475,
          createdAt: now,
          username: 'cashier1',
          stockUpdated: true,
          status: ReceiptStatus.active,
        );

        final entity = model.toEntity();

        expect(entity, isA<ReceiptEntity>());
        expect(entity.id, 'r1');
        expect(entity.shiftId, 's1');
        expect(entity.orderNumber, 'ORD-1');
        expect(entity.items.length, 2);
        expect(entity.subtotalPiastres, 2500);
        expect(entity.discountPiastres, 250);
        expect(entity.taxPiastres, 225);
        expect(entity.totalPiastres, 2475);
        expect(entity.createdAt, now);
        expect(entity.username, 'cashier1');
        expect(entity.stockUpdated, true);
        expect(entity.status, ReceiptStatus.active);
      });
    });
  });

  group('AppReceiptModelAdapter', () {
    late LazyBox<AppReceiptModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppReceiptModelAdapter());
      Hive.registerAdapter(ReceiptItemAdapter());
    });

    setUp(() async {
      box = await Hive.openLazyBox<AppReceiptModel>('test_receipts');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_receipts');
    });

    test('should persist and retrieve model via Hive', () async {
      final model = AppReceiptModel(
        id: 'hive-1',
        shiftId: 'shift-1',
        orderNumber: 'ORD-00001',
        items: items,
        subtotalPiastres: 2500,
        discountPiastres: 250,
        taxPiastres: 225,
        totalPiastres: 2475,
        createdAt: now,
        username: 'cashier1',
        stockUpdated: true,
        status: ReceiptStatus.active,
      );

      await box.put('hive-1', model);
      final retrieved = await box.get('hive-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'hive-1');
      expect(retrieved.shiftId, 'shift-1');
      expect(retrieved.orderNumber, 'ORD-00001');
      expect(retrieved.items.length, 2);
      expect(retrieved.items[0].name, 'Pen');
      expect(retrieved.items[1].name, 'Notebook');
      expect(retrieved.subtotalPiastres, 2500);
      expect(retrieved.discountPiastres, 250);
      expect(retrieved.taxPiastres, 225);
      expect(retrieved.totalPiastres, 2475);
      expect(retrieved.createdAt, now);
      expect(retrieved.username, 'cashier1');
      expect(retrieved.stockUpdated, true);
      expect(retrieved.status, ReceiptStatus.active);
    });

    test('should have typeId 4', () {
      expect(AppReceiptModelAdapter().typeId, 4);
    });

    test('persists amountPaid and paymentType across reopen', () async {
      final model = AppReceiptModel(
        id: 'hive-paid-1',
        shiftId: 'shift-1',
        orderNumber: 'ORD-00002',
        items: items,
        subtotalPiastres: 2500,
        discountPiastres: 0,
        taxPiastres: 225,
        totalPiastres: 2725,
        createdAt: now,
        username: 'cashier1',
        stockUpdated: true,
        status: ReceiptStatus.active,
        amountPaidPiastres: 3000,
        paymentType: 'card',
      );

      await box.put('hive-paid-1', model);
      await box.close();
      box = await Hive.openLazyBox<AppReceiptModel>('test_receipts');
      final retrieved = await box.get('hive-paid-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.amountPaidPiastres, 3000);
      expect(retrieved.paymentType, 'card');
    });
  });
}
