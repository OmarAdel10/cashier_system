import 'dart:convert';
import 'dart:io';

class PrintService {
  final String baseUrl;
  HttpClient? _client;

  PrintService({this.baseUrl = 'http://localhost:5150'}) {
    _client = HttpClient();
  }

  Future<List<String>> getLocalPrinters() async {
    final request = await _client!.getUrl(Uri.parse('$baseUrl/api/printing/local-printers'));
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final List<dynamic> data = json.decode(body);
      return data.cast<String>();
    }
    throw Exception('Failed to fetch printers: ${response.statusCode}');
  }

  Future<void> printReceipt(Map<String, dynamic> payload) async {
    final request = await _client!.postUrl(Uri.parse('$baseUrl/api/printing/receipt'));
    request.headers.contentType = ContentType.json;
    request.write(json.encode(payload));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception('Print receipt failed: $body');
    }
  }

  Future<void> printBarcode(Map<String, dynamic> payload) async {
    final request = await _client!.postUrl(Uri.parse('$baseUrl/api/printing/barcode'));
    request.headers.contentType = ContentType.json;
    request.write(json.encode(payload));
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception('Print barcode failed: $body');
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}
