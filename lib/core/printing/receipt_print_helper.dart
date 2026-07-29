import 'dart:io';

import '../../features/receipts/domain/entities/receipt_entity.dart';
import '../../features/settings/domain/entities/app_settings_entity.dart';
import 'print_service.dart';

class ReceiptPrintHelper {
  ReceiptPrintHelper._();

  static Future<String> _getOutputDir(AppSettingsEntity settings) async {
    String path;
    if (settings.exportDirectoryPath.isNotEmpty) {
      path = settings.exportDirectoryPath;
    } else {
      final home = Platform.environment['USERPROFILE'] ?? '';
      path = '$home\\Downloads';
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      path = Directory.systemTemp.path;
    }
    return path;
  }

  static Map<String, dynamic> buildPayload({
    required ReceiptEntity receipt,
    required AppSettingsEntity settings,
    required DateTime? shiftStartedAt,
    required String outputDir,
    bool saveAsPng = false,
    bool skipPrint = false,
    String? printerName,
  }) {
    return {
      'id': receipt.id,
      'printer_name': printerName ?? settings.receiptPrinterName ?? '',
      'store_name': settings.storeName,
      'store_address': settings.storeAddress,
      'store_phone': settings.storePhoneNumber,
      'order_number': receipt.orderNumber,
      'username': receipt.username,
      'created_at': receipt.createdAt.toIso8601String(),
      'is_rtl': settings.isRtl,
      'save_as_png': saveAsPng,
      'skip_print': skipPrint,
      'outputDirectory': outputDir,
      'logo_svg_data': settings.logoSvgData,
      'shift_started_at': shiftStartedAt?.toIso8601String() ?? '',
      'tax_percent': receipt.taxPercent,
      'discount_percent': receipt.discountPercent,
      'items': receipt.items.map((item) => {
        'name': item.name,
        'barcode': item.barcode,
        'quantity': item.quantity,
        'unit_price_piastres': item.unitPricePiastres,
        'total_piastres': item.unitPricePiastres * item.quantity,
      }).toList(),
      'subtotal_piastres': receipt.subtotalPiastres,
      'discount_piastres': receipt.discountPiastres,
      'tax_piastres': receipt.taxPiastres,
      'total_piastres': receipt.totalPiastres,
      'footnote': settings.receiptFootnote,
    };
  }

  static Future<void> printReceipt({
    required ReceiptEntity receipt,
    required AppSettingsEntity settings,
    required DateTime? shiftStartedAt,
    String? printerName,
  }) async {
    final outputDir = await _getOutputDir(settings);
    final payload = buildPayload(
      receipt: receipt,
      settings: settings,
      shiftStartedAt: shiftStartedAt,
      outputDir: outputDir,
      saveAsPng: settings.saveReceiptAsImage,
      skipPrint: settings.saveReceiptAsImage && !settings.autoPrintEnabled,
      printerName: printerName,
    );
    final service = PrintService();
    try {
      await service.printReceipt(payload);
    } finally {
      service.dispose();
    }
  }

  static Future<String> saveAsPng({
    required ReceiptEntity receipt,
    required AppSettingsEntity settings,
    required DateTime? shiftStartedAt,
  }) async {
    final outputDir = await _getOutputDir(settings);
    final payload = buildPayload(
      receipt: receipt,
      settings: settings,
      shiftStartedAt: shiftStartedAt,
      outputDir: outputDir,
      saveAsPng: true,
    );
    final service = PrintService();
    try {
      return await service.saveReceiptPng(payload);
    } finally {
      service.dispose();
    }
  }
}