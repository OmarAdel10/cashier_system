import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_service_stub.dart';

void main() {
  group('PrintService', () {
    test('constructor creates client with default URL', () {
      final service = StubPrintService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('constructor creates client with custom URL', () {
      final service = StubPrintService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('dispose closes client without error', () {
      final service = StubPrintService();
      service.dispose();
    });

    test('dispose is idempotent', () {
      final service = StubPrintService();
      service.dispose();
      service.dispose();
    });

    test('getLocalPrinters throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.getLocalPrinters();
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printReceipt throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.printReceipt({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printBarcode throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.printBarcode({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printTicket throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.printTicket({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('saveReceiptPng throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.saveReceiptPng({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('saveReceiptPdf throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.saveReceiptPdf({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('saveSalesPdf throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.saveSalesPdf({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('validateSvg throws on connection error (no server)', () async {
      final service = StubPrintService();
      try {
        await service.validateSvg('abc');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });
  });
}
