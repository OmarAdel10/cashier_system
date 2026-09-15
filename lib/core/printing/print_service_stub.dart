// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Print Service stub for unsupported platforms.
abstract class PrintService {
  /// Prints a receipt.
  Future<void> printReceipt(Map<String, dynamic> data);

  /// Prints a barcode.
  Future<void> printBarcode(Map<String, dynamic> data);

  /// Prints a ticket.
  Future<void> printTicket(Map<String, dynamic> data);

  /// Saves receipt as PNG.
  Future<String> saveReceiptPng(Map<String, dynamic> data);

  /// Saves receipt as PDF.
  Future<String> saveReceiptPdf(Map<String, dynamic> data);

  /// Saves sales report as PDF.
  Future<String> saveSalesPdf(Map<String, dynamic> data);

  /// Validates SVG.
  Future<List<String>> validateSvg(String base64Data);

  /// Checks if PrintServer is healthy.
  Future<bool> healthCheck();

  /// Disposes resources.
  void dispose();
}

/// Stub implementation for unsupported platforms.
class PrintServiceStub implements PrintService {
  @override
  Future<void> printReceipt(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<void> printBarcode(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<void> printTicket(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<String> saveReceiptPng(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<String> saveReceiptPdf(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<String> saveSalesPdf(Map<String, dynamic> data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<List<String>> validateSvg(String base64Data) async {
    throw UnsupportedError('Printing not supported on this platform');
  }

  @override
  Future<bool> healthCheck() async => false;

  @override
  void dispose() {}
}
