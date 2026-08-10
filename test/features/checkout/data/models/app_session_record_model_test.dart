import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/data/models/app_session_record_model.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

void main() {
  group('AppSessionRecordModel', () {
    const cola = TableOrderLine(
      name: 'Cola',
      barcode: 'PROD-1',
      quantity: 2,
      unitPricePiastres: 1500,
      prepCategory: PrepCategory.beverage,
    );

    const entity = SessionRecordEntity(
      id: 'SR-1',
      shiftId: 'SHIFT-1',
      stationId: 'PS4-1',
      stationName: 'PS4-1',
      parentCategory: 'PS4',
      tier: SessionTier.multi,
      startTime: null,
      endTime: null,
      durationMinutes: 90,
      wasFixedDuration: true,
      fixedDurationMinutes: 90,
      hourlyRate: 75.0,
      minimumGameCost: 150,
      subtotalPiastres: 11250,
      discountPiastres: 1250,
      taxPiastres: 500,
      totalPiastres: 10500,
      taxPercent: 5,
      discountPercent: 10,
      username: 'cashier1',
      paymentType: 'visa',
      amountPaidPiastres: 10500,
      status: SessionRecordStatus.completed,
      addonLines: [cola],
    );

    test('fromEntity keeps discount and tax fields', () {
      final model = AppSessionRecordModel.fromEntity(entity);
      expect(model.discountPercent, 10);
      expect(model.discountPiastres, 1250);
      expect(model.taxPercent, 5);
      expect(model.taxPiastres, 500);
      expect(model.totalPiastres, 10500);
      expect(model.username, 'cashier1');
      expect(model.paymentType, 'visa');
      expect(model.amountPaidPiastres, 10500);
    });

    test('toEntity round-trips discount and tax fields', () {
      final model = AppSessionRecordModel.fromEntity(entity);
      final restored = model.toEntity();
      expect(restored.id, 'SR-1');
      expect(restored.tier, SessionTier.multi);
      expect(restored.durationMinutes, 90);
      expect(restored.subtotalPiastres, 11250);
      expect(restored.discountPiastres, 1250);
      expect(restored.discountPercent, 10);
      expect(restored.taxPiastres, 500);
      expect(restored.taxPercent, 5);
      expect(restored.totalPiastres, 10500);
      expect(restored.username, 'cashier1');
      expect(restored.paymentType, 'visa');
      expect(restored.amountPaidPiastres, 10500);
    });

    test('toEntity round-trips addon lines', () {
      final model = AppSessionRecordModel.fromEntity(entity);
      final restored = model.toEntity();
      expect(restored.addonLines, [cola]);
      expect(restored.addonLines.first.barcode, 'PROD-1');
      expect(restored.addonLines.first.quantity, 2);
      expect(restored.addonLines.first.unitPricePiastres, 1500);
    });

    test('defaults discount and tax to zero', () {
      const plain = SessionRecordEntity(
        id: 'SR-2',
        shiftId: '',
        stationId: 'PS4-1',
        stationName: 'PS4-1',
        parentCategory: 'PS4',
        tier: SessionTier.normal,
        subtotalPiastres: 5000,
        totalPiastres: 5000,
      );
      expect(plain.discountPercent, 0);
      expect(plain.discountPiastres, 0);
      expect(plain.taxPercent, 0);
      expect(plain.taxPiastres, 0);
    });
  });
}
