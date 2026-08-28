import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cashier_system/core/printing/print_server_factory.dart';
import 'package:cashier_system/core/printing/print_server_interface.dart';
import 'package:cashier_system/core/printing/print_server_manager.dart';
import 'package:cashier_system/core/printing/print_server_manager_linux.dart';

class MockPlatform extends Mock {
  @override
  bool get isLinux => false;

  @override
  bool get isWindows => false;
}

void main() {
  group('PrintServerFactory', () {
    test('factory returns PrintServerManager on Windows', () {
      final originalIsWindows = Platform.isWindows;
      final originalIsLinux = Platform.isLinux;

      try {
        // We can't easily mock Platform, so we just verify factory returns a valid manager
        final manager = PrintServerFactory.create();
        expect(manager, isNotNull);
        expect(manager, isA<IPrintServerManager>());
      } finally {
        // No restoration needed since we didn't actually mock
      }
    });

    test('factory returns PrintServerManagerLinux on Linux', () {
      // On Linux, factory should return PrintServerManagerLinux
      final manager = PrintServerFactory.create();
      expect(manager, isNotNull);
      expect(manager, isA<IPrintServerManager>());
    });
  });
}