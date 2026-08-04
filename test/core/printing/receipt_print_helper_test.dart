import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/receipt_print_helper.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  final testItem = ReceiptItem(
    name: 'Test Item',
    barcode: '123456',
    quantity: 2,
    unitPricePiastres: 1500,
  );

  final testReceipt = ReceiptEntity(
    id: 'r1',
    shiftId: 's1',
    orderNumber: 'ORD-001',
    items: [testItem],
    subtotalPiastres: 3000,
    discountPiastres: 0,
    taxPiastres: 420,
    totalPiastres: 3420,
    taxPercent: 14,
    discountPercent: 0,
    createdAt: DateTime(2026, 1, 15, 10, 30),
    username: 'cashier1',
  );

  final testSettings = AppSettingsEntity(
    storeName: 'Test Store',
    storeAddress: '123 Main St',
    storePhoneNumber: '+20123456789',
    receiptPrinterName: 'Printer1',
    receiptFootnote: 'Thank you!',
    saveReceiptAsImage: false,
    autoPrintEnabled: true,
    exportDirectoryPath: '',
    languageCode: 'en',
  );

  final shiftStartedAt = DateTime(2026, 1, 15, 8, 0);

  group('buildPayload', () {
    test('builds correct map with full data', () {
      final payload = ReceiptPrintHelper.buildPayload(
        receipt: testReceipt,
        settings: testSettings,
        shiftStartedAt: shiftStartedAt,
        outputDir: 'C:\\receipts',
      );

      expect(payload['id'], 'r1');
      expect(payload['store_name'], 'Test Store');
      expect(payload['store_address'], '123 Main St');
      expect(payload['store_phone'], '+20123456789');
      expect(payload['order_number'], 'ORD-001');
      expect(payload['username'], 'cashier1');
      expect(payload['printer_name'], 'Printer1');
      expect(payload['save_as_png'], false);
      expect(payload['skip_print'], false);
      expect(payload['outputDirectory'], 'C:\\receipts');
      expect(payload['tax_percent'], 14);
      expect(payload['discount_percent'], 0);
      expect(payload['footnote'], 'Thank you!');
      expect(payload['total_piastres'], 3420);
    });

    test('buildPayload — items mapped correctly', () {
      final payload = ReceiptPrintHelper.buildPayload(
        receipt: testReceipt,
        settings: testSettings,
        shiftStartedAt: shiftStartedAt,
        outputDir: '/tmp/receipts',
      );

      expect(payload['items'], isA<List>());
      expect((payload['items'] as List).length, 1);

      final item = (payload['items'] as List).first as Map<String, dynamic>;
      expect(item['name'], 'Test Item');
      expect(item['barcode'], '123456');
      expect(item['quantity'], 2);
      expect(item['unit_price_piastres'], 1500);
      expect(item['total_piastres'], 1500 * 2);
    });

    test('buildPayload — handles optional fields defaulted', () {
      final minimalReceipt = ReceiptEntity(
        id: 'r2',
        shiftId: 's1',
        orderNumber: 'ORD-002',
        items: [],
        subtotalPiastres: 0,
        totalPiastres: 0,
        createdAt: DateTime(2026, 1, 1),
        username: 'cashier1',
      );

      final minimalSettings = AppSettingsEntity(
        storeName: 'Store',
      );

      final payload = ReceiptPrintHelper.buildPayload(
        receipt: minimalReceipt,
        settings: minimalSettings,
        shiftStartedAt: null,
        outputDir: '/tmp',
      );

      expect(payload['items'], isEmpty);
      expect(payload['printer_name'], '');
      expect(payload['store_name'], 'Store');
      expect(payload['store_address'], '');
      expect(payload['store_phone'], '');
      expect(payload['shift_started_at'], '');
      expect(payload['footnote'], 'Thanks');
      expect(payload['save_as_png'], false);
      expect(payload['skip_print'], false);
    });

    test('buildPayload — skipPrint and saveAsPng flags', () {
      final payload = ReceiptPrintHelper.buildPayload(
        receipt: testReceipt,
        settings: testSettings,
        shiftStartedAt: shiftStartedAt,
        outputDir: '/tmp',
        saveAsPng: true,
        skipPrint: true,
      );

      expect(payload['save_as_png'], true);
      expect(payload['skip_print'], true);
    });

    test('buildPayload — uses custom printerName when provided', () {
      final payload = ReceiptPrintHelper.buildPayload(
        receipt: testReceipt,
        settings: testSettings,
        shiftStartedAt: shiftStartedAt,
        outputDir: '/tmp',
        printerName: 'CustomPrinter',
      );

      expect(payload['printer_name'], 'CustomPrinter');
    });

    test('buildPayload — includes receipt id', () {
      final payload = ReceiptPrintHelper.buildPayload(
        receipt: testReceipt,
        settings: testSettings,
        shiftStartedAt: shiftStartedAt,
        outputDir: '/tmp',
      );
      expect(payload['id'], testReceipt.id);
    });
  });
}
