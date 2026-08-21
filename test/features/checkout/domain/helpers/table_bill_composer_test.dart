import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/domain/helpers/table_bill_composer.dart';

const koshary = TableOrderLine(
  name: 'Koshary',
  barcode: 'K1',
  quantity: 5,
  unitPricePiastres: 1000,
  prepCategory: PrepCategory.food,
);
const cola = TableOrderLine(
  name: 'Cola',
  barcode: 'C1',
  quantity: 2,
  unitPricePiastres: 500,
  prepCategory: PrepCategory.beverage,
);

void main() {
  group('compose', () {
    test('pure items bill mirrors CheckoutBloc math', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.takeaway,
        firedLines: const [koshary, cola],
        draftLines: const [],
        discountPercent: 10,
        taxPercent: 5,
      ).compose();

      expect(bill.itemsSum, 6000);
      expect(bill.roomChargePiastres, 0);
      expect(bill.serviceChargePiastres, 0);
      expect(bill.minChargeDeltaPiastres, 0);
      expect(bill.subtotalPiastres, 6000);
      expect(bill.discountPiastres, 600);
      expect(bill.taxPiastres, 300);
      expect(bill.totalPiastres, 5700);
    });

    test('draft lines are included in the base', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        firedLines: const [koshary],
        draftLines: const [cola],
      ).compose();

      expect(bill.itemsSum, 6000);
      expect(bill.subtotalPiastres, 6000);
    });

    test('room charge adds chargedHours x hourlyRate to base', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.takeaway,
        isRoom: true,
        chargedHours: 3,
        hourlyRatePiastres: 2000,
        firedLines: const [koshary],
        draftLines: const [],
      ).compose();

      expect(bill.roomChargePiastres, 6000);
      expect(bill.subtotalPiastres, 11000);
      expect(bill.items.length, 2); // koshary + room item
      final room = bill.items.last;
      expect(room.quantity, 1);
      expect(room.unitPricePiastres, 6000);
    });

    test('min charge floor applies only when enabled and dine-in', () {
      final low = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        minChargeEnabled: true,
        minChargePerTablePiastres: 1000,
        firedLines: const [
          TableOrderLine(
            name: 'Tea',
            barcode: 'T1',
            quantity: 1,
            unitPricePiastres: 100,
          ),
        ],
        draftLines: const [],
      ).compose();
      expect(low.minChargeDeltaPiastres, 900);
      expect(low.subtotalPiastres, 1000);

      final disabled = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        minChargeEnabled: false,
        minChargePerTablePiastres: 1000,
        firedLines: const [
          TableOrderLine(
            name: 'Tea',
            barcode: 'T1',
            quantity: 1,
            unitPricePiastres: 100,
          ),
        ],
        draftLines: const [],
      ).compose();
      expect(disabled.minChargeDeltaPiastres, 0);
      expect(disabled.subtotalPiastres, 100);

      final takeaway = TableBillComposer(
        zoneKind: ZoneKind.takeaway,
        minChargeEnabled: true,
        minChargePerTablePiastres: 1000,
        firedLines: const [
          TableOrderLine(
            name: 'Tea',
            barcode: 'T1',
            quantity: 1,
            unitPricePiastres: 100,
          ),
        ],
        draftLines: const [],
      ).compose();
      expect(takeaway.minChargeDeltaPiastres, 0);
      expect(takeaway.subtotalPiastres, 100);
    });

    test('service charge percent applies only when enabled and dine-in', () {
      final dineIn = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        serviceChargeEnabled: true,
        serviceChargePercent: 12,
        firedLines: const [koshary],
        draftLines: const [],
      ).compose();
      expect(dineIn.serviceChargePiastres, 600);
      expect(dineIn.subtotalPiastres, 5600);

      final takeaway = TableBillComposer(
        zoneKind: ZoneKind.takeaway,
        serviceChargeEnabled: true,
        serviceChargePercent: 12,
        firedLines: const [koshary],
        draftLines: const [],
      ).compose();
      expect(takeaway.serviceChargePiastres, 0);
      expect(takeaway.subtotalPiastres, 5000);
    });

    test('discount percent is clamped to 0..100 like CheckoutBloc', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.takeaway,
        firedLines: const [koshary],
        draftLines: const [],
        discountPercent: 150,
      ).compose();
      expect(bill.discountPercent, 100);
      expect(bill.discountPiastres, 5000);
    });
  });

  group('split', () {
    test('single split equals the full bill', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        isRoom: true,
        chargedHours: 2,
        hourlyRatePiastres: 1000,
        firedLines: const [koshary, cola],
        draftLines: const [],
        minChargeEnabled: true,
        minChargePerTablePiastres: 5000,
        serviceChargeEnabled: true,
        serviceChargePercent: 10,
        discountPercent: 10,
        taxPercent: 5,
      ).compose();
      final splits = bill.split(1);

      expect(splits.length, 1);
      expect(splits.single.subtotalPiastres, bill.subtotalPiastres);
      expect(splits.single.discountPiastres, bill.discountPiastres);
      expect(splits.single.taxPiastres, bill.taxPiastres);
      expect(splits.single.totalPiastres, bill.totalPiastres);
    });

    test('split preserves totals and gives remainders to the last receipt', () {
      final bill = TableBillComposer(
        zoneKind: ZoneKind.dineIn,
        isRoom: true,
        chargedHours: 2,
        hourlyRatePiastres: 1000,
        firedLines: const [koshary, cola],
        draftLines: const [],
        minChargeEnabled: true,
        minChargePerTablePiastres: 5000,
        serviceChargeEnabled: true,
        serviceChargePercent: 10,
        discountPercent: 10,
        taxPercent: 5,
      ).compose();

      final splits = bill.split(3);

      expect(splits.length, 3);
      var sumItems = 0;
      var sumSub = 0;
      var sumDisc = 0;
      var sumTax = 0;
      var sumTotal = 0;
      final sumQty = <String, int>{};
      for (final s in splits) {
        sumSub += s.subtotalPiastres;
        sumDisc += s.discountPiastres;
        sumTax += s.taxPiastres;
        sumTotal += s.totalPiastres;
        for (final item in s.items) {
          sumItems += item.quantity * item.unitPricePiastres;
          sumQty[item.name] = (sumQty[item.name] ?? 0) + item.quantity;
        }
      }

      expect(sumSub, bill.subtotalPiastres);
      expect(sumDisc, bill.discountPiastres);
      expect(sumTax, bill.taxPiastres);
      expect(sumTotal, bill.totalPiastres);
      expect(sumItems, bill.subtotalPiastres); // includes room/service extras
      expect(sumQty['Koshary'], 5);
      expect(sumQty['Cola'], 2);

      // each receipt satisfies receipts-bloc financial validation exactly
      for (final s in splits) {
        final itemSum = s.items.fold(
          0,
          (acc, i) => acc + i.quantity * i.unitPricePiastres,
        );
        expect(itemSum, s.subtotalPiastres);
        expect(
          s.totalPiastres,
          s.subtotalPiastres - s.discountPiastres + s.taxPiastres,
        );
      }
    });

    test('splitAmount gives remainder to the last part', () {
      expect(ComposedTableBill.splitAmount(1000, 3), [333, 333, 334]);
      expect(ComposedTableBill.splitAmount(1000, 1), [1000]);
      expect(ComposedTableBill.splitAmount(5, 4), [1, 1, 1, 2]);
    });
  });
}
