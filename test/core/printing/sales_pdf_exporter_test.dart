import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/sales_pdf_exporter.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  group('SalesPdfExporter.buildPayload', () {
    final sale = ReceiptEntity(
      id: 'r1',
      shiftId: 's1',
      orderNumber: 'ORD-001',
      items: const [
        ReceiptItem(
          name: 'Pepsi',
          barcode: '1',
          quantity: 2,
          unitPricePiastres: 500,
        ),
        ReceiptItem(
          name: 'Water',
          barcode: '2',
          quantity: 1,
          unitPricePiastres: 500,
        ),
      ],
      subtotalPiastres: 1500,
      discountPiastres: 250,
      taxPiastres: 350,
      totalPiastres: 2600,
      discountPercent: 10,
      taxPercent: 14,
      createdAt: DateTime(2026, 8, 15),
      username: 'cashier1',
    );
    final expense = ReceiptEntity(
      id: 'e1',
      shiftId: 's1',
      orderNumber: 'EXP-123',
      items: const [
        ReceiptItem(
          name: 'Bread',
          barcode: '3',
          quantity: 1,
          unitPricePiastres: 1500,
        ),
      ],
      subtotalPiastres: 1500,
      totalPiastres: 1500,
      createdAt: DateTime(2026, 8, 1),
      username: 'cashier1',
      status: ReceiptStatus.expense,
    );

    test('builds stacked rows payload from receipts and settings', () {
      final payload = SalesPdfExporter.buildPayload(
        receipts: [sale, expense],
        settings: const AppSettingsEntity(
          storeName: 'My Store',
          storeAddress: '12 Main St',
          storePhoneNumber: '0100000000',
          logoSvgData: 'base64logo',
          languageCode: 'ar',
        ),
        title: 'Sales Export - Month 8/2026',
        outputDirectory: r'C:\exports',
      );

      expect(payload['title'], 'Sales Export - Month 8/2026');
      expect(payload['period_start'], '1/8/2026');
      expect(payload['period_end'], '15/8/2026');
      expect(payload['store_name'], 'My Store');
      expect(payload['store_address'], '12 Main St');
      expect(payload['store_phone'], '0100000000');
      expect(payload['logo_svg_data'], 'base64logo');
      expect(payload['is_rtl'], isTrue);
      expect(payload['outputDirectory'], r'C:\exports');

      final rows = payload['rows'] as List;
      expect(rows, hasLength(2));

      final saleRow = rows[0] as Map<String, dynamic>;
      expect(saleRow['type'], 'sale');
      expect(saleRow['id'], 'ORD-001');
      expect(saleRow['date'], '15/8/2026');
      expect(saleRow['cashier'], 'cashier1');
      expect(saleRow['discount_percent'], 10);
      expect(saleRow['tax_percent'], 14);
      expect(saleRow['discount_piastres'], 250);
      expect(saleRow['tax_piastres'], 350);
      expect(saleRow['amount_piastres'], 1500);
      expect(saleRow['total_piastres'], 2600);
      final items = saleRow['items'] as List;
      expect(items, hasLength(2));
      expect(items[0], {'name': 'Pepsi', 'quantity': 2, 'price_piastres': 500});
      expect(items[1], {'name': 'Water', 'quantity': 1, 'price_piastres': 500});

      final expenseRow = rows[1] as Map<String, dynamic>;
      expect(expenseRow['type'], 'expense');
      expect(expenseRow['id'], 'EXP-123');
      expect(expenseRow['date'], '1/8/2026');
      expect(expenseRow['amount_piastres'], 1500);
      expect(expenseRow['total_piastres'], 1500);
      expect(expenseRow['items'], hasLength(1));
    });

    test('empty receipts produce empty rows and blank period', () {
      final payload = SalesPdfExporter.buildPayload(
        receipts: const [],
        settings: const AppSettingsEntity(languageCode: 'en'),
        title: 'Sales Export',
        outputDirectory: r'C:\exports',
      );

      expect(payload['rows'], isEmpty);
      expect(payload['period_start'], '');
      expect(payload['period_end'], '');
      expect(payload['is_rtl'], isFalse);
    });
  });
}
