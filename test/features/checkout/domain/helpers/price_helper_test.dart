import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/checkout/domain/helpers/price_helper.dart';

void main() {
  group('PriceHelper', () {
    group('fromDouble', () {
      test('should convert 15.99 to 1599', () {
        expect(PriceHelper.fromDouble(15.99), 1599);
      });

      test('should convert 0.50 to 50', () {
        expect(PriceHelper.fromDouble(0.50), 50);
      });

      test('should handle whole numbers', () {
        expect(PriceHelper.fromDouble(10.00), 1000);
      });
    });

    group('format', () {
      test('should format 1500 as EGP 15.00', () {
        expect(PriceHelper.format(1500), 'EGP 15.00');
      });

      test('should format 99 as EGP 0.99', () {
        expect(PriceHelper.format(99), 'EGP 0.99');
      });
    });
  });
}
