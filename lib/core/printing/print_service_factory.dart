// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Factory for creating platform-specific PrintService implementations.
import 'print_service_interface.dart';

/// Factory for creating PrintService instances.
class PrintServiceFactory {
  static PrintService? _instance;

  /// Get or create the platform-appropriate PrintService (singleton).
  static PrintService get instance {
    _instance ??= _createService();
    return _instance!;
  }

  /// Create a new platform-specific PrintService instance (non-singleton).
  static PrintService create() {
    return _createService();
  }

  /// Create platform-specific service.
  static PrintService _createService() {
    // Platform detection would go here
    // For now, return stub - actual impl in conditional imports
    return StubPrintService();
  }

  /// Override for testing.
  static void overrideForTesting(PrintService service) {
    _instance = service;
  }

  /// Reset singleton (for testing).
  static void reset() {
    _instance = null;
  }
}

/// Stub implementation for unsupported platforms/testing.
class StubPrintService implements PrintService {
  @override
  String get baseUrl => 'http://localhost:5001';

  @override
  Future<bool> healthCheck() async => false;

  @override
  Future<List<String>> getLocalPrinters() async => [];

  @override
  Future<void> printReceipt(Map<String, dynamic> payload) async {}

  @override
  Future<void> printBarcode(Map<String, dynamic> payload) async {}

  @override
  Future<void> printTicket(Map<String, dynamic> payload) async {}

  @override
  Future<String> saveReceiptPng(Map<String, dynamic> payload) async => '';

  @override
  Future<String> saveReceiptPdf(Map<String, dynamic> payload) async => '';

  @override
  Future<String> saveSalesPdf(Map<String, dynamic> payload) async => '';

  @override
  Future<List<String>> validateSvg(String base64Data) async => [];

  @override
  void dispose() {}
}
