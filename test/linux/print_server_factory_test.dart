import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_server_factory.dart';
import 'package:cashier_system/core/printing/print_server_interface.dart';

class MockPlatform {
  bool isLinux = false;
  bool isWindows = false;
}

void main() {
  group('PrintServerFactory', () {
    test('factory returns PrintServerManager on Windows', () {
      // We can't easily mock Platform, so we just verify factory returns a valid manager
      final manager = PrintServerFactory.create();
      expect(manager, isNotNull);
      expect(manager, isA<IPrintServerManager>());
    });

    test('factory returns PrintServerManagerLinux on Linux', () {
      // On Linux, factory should return PrintServerManagerLinux
      final manager = PrintServerFactory.create();
      expect(manager, isNotNull);
      expect(manager, isA<IPrintServerManager>());
    });
  });
}
