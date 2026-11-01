// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Interface for Print services.
///
/// Each platform implements this interface to communicate with the
/// PrintServer sidecar (.NET) for printing operations.
abstract interface class PrintService {
  /// Base URL for the PrintServer API.
  String get baseUrl;

  /// Get list of local printers from PrintServer.
  Future<List<String>> getLocalPrinters();

  /// Print a thermal receipt.
  Future<void> printReceipt(Map<String, dynamic> payload);

  /// Print a barcode label.
  Future<void> printBarcode(Map<String, dynamic> payload);

  /// Print a ticket (kitchen, bar, shisha).
  Future<void> printTicket(Map<String, dynamic> payload);

  /// Save receipt as PNG image.
  Future<String> saveReceiptPng(Map<String, dynamic> payload);

  /// Save receipt as PDF invoice (A4).
  Future<String> saveReceiptPdf(Map<String, dynamic> payload);

  /// Save sales report as PDF (A4 landscape).
  Future<String> saveSalesPdf(Map<String, dynamic> payload);

  /// Validate SVG logo (base64 encoded).
  Future<List<String>> validateSvg(String base64Data);

  /// Check if PrintServer is running and healthy.
  Future<bool> healthCheck();

  /// Dispose resources.
  void dispose();
}

/// Exception thrown when print operations fail.
class PrintException implements Exception {
  final String message;
  final String? endpoint;
  final int? statusCode;
  final Object? originalError;

  const PrintException(
    this.message, {
    this.endpoint,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PrintException');
    if (endpoint != null) {
      buffer.write(' ($endpoint)');
    }
    if (statusCode != null) {
      buffer.write(' [HTTP $statusCode]');
    }
    buffer.write(': $message');
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }
}
