// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'print_service_interface.dart';

/// Stub Print Service for unsupported platforms (web, macOS, etc.).
///
/// This implementation throws [PrintException] for all operations.
/// It exists to satisfy the conditional import system.
class StubPrintService implements PrintService {
  @override
  String get baseUrl => 'unsupported';

  @override
  Future<List<String>> getLocalPrinters() async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/local-printers',
    );
  }

  @override
  Future<void> printReceipt(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/print-receipt',
    );
  }

  @override
  Future<void> printBarcode(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/print-barcode',
    );
  }

  @override
  Future<void> printTicket(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/print-ticket',
    );
  }

  @override
  Future<String> saveReceiptPng(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/save-png',
    );
  }

  @override
  Future<String> saveReceiptPdf(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/save-pdf',
    );
  }

  @override
  Future<String> saveSalesPdf(Map<String, dynamic> payload) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/sales-export',
    );
  }

  @override
  Future<List<String>> validateSvg(String base64Data) async {
    throw PrintException(
      'Printing is not supported on this platform',
      endpoint: '/api/printing/validate-svg',
    );
  }

  @override
  Future<bool> healthCheck() async => false;

  @override
  void dispose() {}
}
