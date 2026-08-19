import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_service.dart';

void main() {
  group('PrintService', () {
    test('constructor creates client with default URL', () {
      final service = PrintService();
      expect(service, isNotNull);
      service.dispose();
    });

    test('constructor creates client with custom URL', () {
      final service = PrintService(baseUrl: 'http://custom:8080');
      expect(service, isNotNull);
      service.dispose();
    });

    test('dispose closes client without error', () {
      final service = PrintService();
      service.dispose();
    });

    test('dispose is idempotent', () {
      final service = PrintService();
      service.dispose();
      service.dispose();
    });

    test('getLocalPrinters throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.getLocalPrinters();
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printReceipt throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.printReceipt({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printBarcode throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.printBarcode({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('printTicket throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.printTicket({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('saveReceiptPng throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.saveReceiptPng({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('saveReceiptPdf throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
      try {
        await service.saveReceiptPdf({'test': true});
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }
      service.dispose();
    });

    test('validateSvg throws on connection error (no server)', () async {
      final service = PrintService(baseUrl: 'http://localhost:1');
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
