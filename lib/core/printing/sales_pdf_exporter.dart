import '../../features/receipts/domain/entities/receipt_entity.dart';
import '../../features/receipts/domain/entities/receipt_status.dart';
import '../../features/settings/domain/entities/app_settings_entity.dart';
import 'print_service.dart';

/// Builds the SalesExportRequest payload from the same receipts the CSV
/// export uses (one row per transaction, stacked line items) and asks
/// PrintServer to render the A4 landscape sales PDF
/// (sales_export_template.html). The store header info comes from the
/// settings provider so the report matches the receipt branding.
class SalesPdfExporter {
  SalesPdfExporter({
    PrintService? printService,
    required AppSettingsEntity Function() settingsProvider,
  }) : _printService = printService ?? PrintService(),
       _settingsProvider = settingsProvider;

  final PrintService _printService;
  final AppSettingsEntity Function() _settingsProvider;

  /// Renders the report via PrintServer and returns the saved PDF path.
  Future<String> saveAsPdf({
    required List<ReceiptEntity> receipts,
    required String title,
    required String outputDirectory,
  }) async {
    final payload = buildPayload(
      receipts: receipts,
      settings: _settingsProvider(),
      title: title,
      outputDirectory: outputDirectory,
    );
    return _printService.saveSalesPdf(payload);
  }

  void dispose() => _printService.dispose();

  /// Builds the JSON payload for POST /api/printing/sales-export.
  /// The period is derived from the earliest/latest receipt date; the
  /// PrintServer derives the summary stats and totals from the rows.
  static Map<String, dynamic> buildPayload({
    required List<ReceiptEntity> receipts,
    required AppSettingsEntity settings,
    required String title,
    required String outputDirectory,
  }) {
    String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

    final dates = receipts.map((r) => r.createdAt).toList()..sort();
    return {
      'title': title,
      'period_start': dates.isEmpty ? '' : formatDate(dates.first),
      'period_end': dates.isEmpty ? '' : formatDate(dates.last),
      'store_name': settings.storeName,
      'store_address': settings.storeAddress,
      'store_phone': settings.storePhoneNumber,
      'logo_svg_data': settings.logoSvgData,
      'is_rtl': settings.isRtl,
      'outputDirectory': outputDirectory,
      'rows': [
        for (final receipt in receipts)
          {
            'type': receipt.status == ReceiptStatus.expense
                ? 'expense'
                : 'sale',
            'id': receipt.orderNumber,
            'date': formatDate(receipt.createdAt),
            'cashier': receipt.username,
            'discount_percent': receipt.discountPercent,
            'tax_percent': receipt.taxPercent,
            'discount_piastres': receipt.discountPiastres,
            'tax_piastres': receipt.taxPiastres,
            'amount_piastres': receipt.items.fold<int>(
              0,
              (sum, item) => sum + item.totalPiastres,
            ),
            'total_piastres': receipt.totalPiastres,
            'items': [
              for (final item in receipt.items)
                {
                  'name': item.name,
                  'quantity': item.quantity,
                  'price_piastres': item.unitPricePiastres,
                },
            ],
          },
      ],
    };
  }
}
