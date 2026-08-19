import 'dart:convert';
import 'dart:io';

class PrintService {
  final String baseUrl;
  HttpClient? _client;

  PrintService({this.baseUrl = 'http://localhost:5150'}) {
    _client = HttpClient();
  }

  Future<List<String>> getLocalPrinters() async {
    try {
      final request = await _client!.getUrl(
        Uri.parse('$baseUrl/api/printing/local-printers'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = json.decode(body);
        return data.cast<String>();
      }
      throw Exception('Failed to fetch printers: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get local printers: $e');
    }
  }

  Future<void> printReceipt(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/receipt'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Print receipt failed: $body');
      }
    } catch (e) {
      throw Exception('Print receipt failed: $e');
    }
  }

  Future<void> printBarcode(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/barcode'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Print barcode failed: $body');
      }
    } catch (e) {
      throw Exception('Print barcode failed: $e');
    }
  }

  /// Prints a kitchen/bar/shisha ticket for a fired round. The ticket
  /// payload carries venue info, table/zone/round, order number and
  /// qty x name lines only — no prices, totals or tax.
  Future<void> printTicket(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/ticket'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Print ticket failed: $body');
      }
    } catch (e) {
      throw Exception('Print ticket failed: $e');
    }
  }

  Future<String> saveReceiptPng(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/save-png'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Save PNG failed: $body');
      }
      final body = await response.transform(utf8.decoder).join();
      return (json.decode(body)['pngPath'] as String);
    } catch (e) {
      throw Exception('Save receipt PNG failed: $e');
    }
  }

  /// Asks PrintServer to render the receipt payload as an A4 PDF invoice
  /// (see [saveReceiptPng] for the equivalent PNG flow).
  ///
  /// Returns the path of the saved PDF on success; throws on transport or
  /// server errors.
  Future<String> saveReceiptPdf(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/save-pdf'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Save PDF failed: $body');
      }
      final body = await response.transform(utf8.decoder).join();
      return (json.decode(body)['pdfPath'] as String);
    } catch (e) {
      throw Exception('Save receipt PDF failed: $e');
    }
  }

  /// Asks PrintServer to render the sales report payload as a stacked
  /// A4 landscape PDF (see sales_export_template.html).
  ///
  /// Returns the path of the saved PDF on success; throws on transport or
  /// server errors.
  Future<String> saveSalesPdf(Map<String, dynamic> payload) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/sales-export'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode(payload));
      final response = await request.close();
      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw Exception('Save sales export PDF failed: $body');
      }
      final body = await response.transform(utf8.decoder).join();
      return (json.decode(body)['pdfPath'] as String);
    } catch (e) {
      throw Exception('Save sales export PDF failed: $e');
    }
  }

  /// Asks PrintServer to validate an SVG logo (base64 encoded).
  ///
  /// Returns the list of error codes on rejection; throws on transport or
  /// server errors so callers can distinguish "invalid file" from
  /// "server unreachable".
  Future<List<String>> validateSvg(String base64Data) async {
    try {
      final request = await _client!.postUrl(
        Uri.parse('$baseUrl/api/printing/validate-svg'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode({'data': base64Data}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('SVG validation failed: $body');
      }
      final decoded = json.decode(body);
      final valid = decoded['valid'] as bool? ?? false;
      if (valid) return const [];
      return (decoded['errors'] as List<dynamic>? ?? const []).cast<String>();
    } catch (e) {
      throw Exception('SVG validation failed: $e');
    }
  }

  void dispose() {
    try {
      _client?.close();
      _client = null;
    } catch (e) {
      // Ignore disposal errors
    }
  }
}
