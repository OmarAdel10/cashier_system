// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_service_factory.dart';
import 'package:cashier_system/core/printing/print_service_interface.dart';

void main() {
  group('PrintServiceFactory', () {
    test('returns StubPrintService by default', () {
      PrintServiceFactory.reset();
      final service = PrintServiceFactory.instance;
      expect(service, isA<StubPrintService>());
    });

    test('create returns new StubPrintService', () {
      final service = PrintServiceFactory.create();
      expect(service, isA<StubPrintService>());
    });

    test('can override for testing', () {
      final mockService = MockPrintService();
      PrintServiceFactory.overrideForTesting(mockService);
      expect(PrintServiceFactory.instance, same(mockService));
      PrintServiceFactory.reset();
    });
  });
}

class MockPrintService implements PrintService {
  @override
  String get baseUrl => 'http://test:5001';

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<String>> getLocalPrinters() async => ['Test Printer'];

  @override
  Future<void> printReceipt(Map<String, dynamic> payload) async {}

  @override
  Future<void> printBarcode(Map<String, dynamic> payload) async {}

  @override
  Future<void> printTicket(Map<String, dynamic> payload) async {}

  @override
  Future<String> saveReceiptPng(Map<String, dynamic> payload) async =>
      'test.png';

  @override
  Future<String> saveReceiptPdf(Map<String, dynamic> payload) async =>
      'test.pdf';

  @override
  Future<String> saveSalesPdf(Map<String, dynamic> payload) async => 'test.pdf';

  @override
  Future<List<String>> validateSvg(String base64Data) async => [];

  @override
  void dispose() {}
}
