// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'print_service_interface.dart';

/// Linux Print Service implementation using .NET PrintServer.Linux sidecar.
class LinuxPrintService implements PrintService {
  @override
  final String baseUrl;

  final http.Client _client;

  LinuxPrintService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? 'http://127.0.0.1:5150',
      _client = client ?? http.Client();

  @override
  Future<List<String>> getLocalPrinters() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/printing/local-printers'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      }
      throw PrintException(
        'Failed to fetch printers: ${response.statusCode}',
        endpoint: '/api/printing/local-printers',
        statusCode: response.statusCode,
      );
    } on http.ClientException catch (e) {
      throw PrintException(
        'Network error getting printers: $e',
        endpoint: '/api/printing/local-printers',
        originalError: e,
      );
    } catch (e) {
      throw PrintException(
        'Failed to get local printers: $e',
        endpoint: '/api/printing/local-printers',
        originalError: e,
      );
    }
  }

  @override
  Future<void> printReceipt(Map<String, dynamic> payload) async {
    await _post('/api/printing/print-receipt', payload);
  }

  @override
  Future<void> printBarcode(Map<String, dynamic> payload) async {
    await _post('/api/printing/print-barcode', payload);
  }

  @override
  Future<void> printTicket(Map<String, dynamic> payload) async {
    await _post('/api/printing/print-ticket', payload);
  }

  @override
  Future<String> saveReceiptPng(Map<String, dynamic> payload) async {
    final response = await _postWithResponse('/api/printing/save-png', payload);
    return response['pngPath'] as String;
  }

  @override
  Future<String> saveReceiptPdf(Map<String, dynamic> payload) async {
    final response = await _postWithResponse('/api/printing/save-pdf', payload);
    return response['pdfPath'] as String;
  }

  @override
  Future<String> saveSalesPdf(Map<String, dynamic> payload) async {
    final response = await _postWithResponse(
      '/api/printing/sales-export',
      payload,
    );
    return response['pdfPath'] as String;
  }

  @override
  Future<List<String>> validateSvg(String base64Data) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/printing/validate-svg'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'data': base64Data}),
          )
          .timeout(const Duration(seconds: 10));

      final body = json.decode(response.body);
      if (response.statusCode != 200) {
        throw PrintException(
          'SVG validation failed: ${body['message'] ?? response.body}',
          endpoint: '/api/printing/validate-svg',
          statusCode: response.statusCode,
        );
      }

      final valid = body['valid'] as bool? ?? false;
      if (valid) return const <String>[];
      return (body['errors'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>();
    } on http.ClientException catch (e) {
      throw PrintException(
        'Network error validating SVG: $e',
        endpoint: '/api/printing/validate-svg',
        originalError: e,
      );
    } catch (e) {
      throw PrintException(
        'SVG validation failed: $e',
        endpoint: '/api/printing/validate-svg',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _client.close();
  }

  Future<void> _post(String endpoint, Map<String, dynamic> payload) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw PrintException(
          'Print failed: ${response.body}',
          endpoint: endpoint,
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw PrintException(
        'Network error: $e',
        endpoint: endpoint,
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> _postWithResponse(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw PrintException(
          'Request failed: ${response.body}',
          endpoint: endpoint,
          statusCode: response.statusCode,
        );
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } on http.ClientException catch (e) {
      throw PrintException(
        'Network error: $e',
        endpoint: endpoint,
        originalError: e,
      );
    }
  }
}
