import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/inventory/domain/helpers/barcode_generator.dart';

void main() {
  group('generateAutoBarcode', () {
    test('returns a barcode starting with auto- prefix', () {
      final barcode = generateAutoBarcode();
      expect(barcode, startsWith('auto-'));
    });

    test('returns unique barcodes on consecutive calls', () {
      final first = generateAutoBarcode();
      final second = generateAutoBarcode();
      expect(first, isNot(second));
    });
  });

  group('isAutoBarcode', () {
    test('returns true only for auto- prefix', () {
      expect(isAutoBarcode(generateAutoBarcode()), isTrue);
      expect(isAutoBarcode('auto-123'), isTrue);
      expect(isAutoBarcode('123456789012'), isFalse);
      expect(isAutoBarcode(''), isFalse);
    });
  });
}
