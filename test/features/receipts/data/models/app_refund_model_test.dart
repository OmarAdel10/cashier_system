import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cashier_system/features/receipts/data/models/app_refund_model.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';

void main() {
  final now = DateTime(2026, 7, 14, 10, 30, 0);

  group('AppRefundModel', () {
    group('fromJson', () {
      test('should return a valid model with all fields', () {
        final json = {
          'id': 'refund-1',
          'originalReceiptId': 'receipt-1',
          'refundDate': now.toIso8601String(),
          'amountRestored': 2475,
          'type': 0,
        };

        final model = AppRefundModel.fromJson(json);

        expect(model.id, 'refund-1');
        expect(model.originalReceiptId, 'receipt-1');
        expect(model.refundDate, now);
        expect(model.amountRestored, 2475);
        expect(model.type, RefundType.full);
      });

      test('should use defaults for missing fields', () {
        final json = <String, dynamic>{};

        final model = AppRefundModel.fromJson(json);

        expect(model.id, '');
        expect(model.originalReceiptId, '');
        expect(model.refundDate, isA<DateTime>());
        expect(model.amountRestored, 0);
        expect(model.type, RefundType.full);
      });
    });

    group('toJson', () {
      test('should return a valid JSON map', () {
        final model = AppRefundModel(
          id: 'refund-1',
          originalReceiptId: 'receipt-1',
          refundDate: now,
          amountRestored: 2475,
          type: RefundType.full,
        );

        final json = model.toJson();

        expect(json['id'], 'refund-1');
        expect(json['originalReceiptId'], 'receipt-1');
        expect(json['refundDate'], now.toIso8601String());
        expect(json['amountRestored'], 2475);
        expect(json['type'], 0);
      });
    });

    group('round-trip', () {
      test('should serialize and deserialize correctly', () {
        final original = AppRefundModel(
          id: 'rt-1',
          originalReceiptId: 'receipt-2',
          refundDate: now,
          amountRestored: 1500,
          type: RefundType.partial,
        );

        final json = original.toJson();
        final decoded = AppRefundModel.fromJson(json);

        expect(decoded.id, original.id);
        expect(decoded.originalReceiptId, original.originalReceiptId);
        expect(decoded.refundDate, original.refundDate);
        expect(decoded.amountRestored, original.amountRestored);
        expect(decoded.type, original.type);
      });
    });

    group('identity', () {
      test('should be a RefundEntity', () {
        final model = AppRefundModel(
          id: 'rf1',
          originalReceiptId: 'r1',
          refundDate: now,
          amountRestored: 0,
          type: RefundType.full,
        );
        expect(model, isA<RefundEntity>());
      });
    });

    group('toEntity', () {
      test('should convert to RefundEntity preserving all fields', () {
        final model = AppRefundModel(
          id: 'rf1',
          originalReceiptId: 'r1',
          refundDate: now,
          amountRestored: 2475,
          type: RefundType.full,
        );

        final entity = model.toEntity();

        expect(entity, isA<RefundEntity>());
        expect(entity.id, 'rf1');
        expect(entity.originalReceiptId, 'r1');
        expect(entity.refundDate, now);
        expect(entity.amountRestored, 2475);
        expect(entity.type, RefundType.full);
      });
    });

    group('status index mapping', () {
      test('0 maps to RefundType.full', () {
        expect(RefundType.values[0], RefundType.full);
      });

      test('1 maps to RefundType.partial', () {
        expect(RefundType.values[1], RefundType.partial);
      });
    });
  });

  group('AppRefundModelAdapter', () {
    late LazyBox<AppRefundModel> box;

    setUpAll(() async {
      Hive.init('test/_hive_test');
      Hive.registerAdapter(AppRefundModelAdapter());
    });

    setUp(() async {
      box = await Hive.openLazyBox<AppRefundModel>('test_refunds');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_refunds');
    });

    test('should persist and retrieve model via Hive', () async {
      final model = AppRefundModel(
        id: 'hive-1',
        originalReceiptId: 'receipt-1',
        refundDate: now,
        amountRestored: 2475,
        type: RefundType.partial,
      );

      await box.put('hive-1', model);
      final retrieved = await box.get('hive-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'hive-1');
      expect(retrieved.originalReceiptId, 'receipt-1');
      expect(retrieved.refundDate, now);
      expect(retrieved.amountRestored, 2475);
      expect(retrieved.type, RefundType.partial);
    });

    test('should have typeId 5', () {
      expect(AppRefundModelAdapter().typeId, 5);
    });
  });
}
