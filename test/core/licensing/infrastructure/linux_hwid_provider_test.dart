import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/licensing/infrastructure/hwid/linux_hwid_provider.dart';

void main() {
  group('LinuxHwidProvider.formatMachineId', () {
    test('should format last 8 hex chars as CS-XXXX-XXXX', () {
      final result = LinuxHwidProvider.formatMachineId(
        '12345678123456781234567812345678',
      );
      expect(result, 'CS-1234-5678');
    });

    test('should uppercase the extracted tail', () {
      final result = LinuxHwidProvider.formatMachineId(
        'abcdefabcdefabcdefabcdefabcdefab',
      );
      expect(result, 'CS-ABCD-EFAB');
    });

    test('should ignore trailing newline (file content layout)', () {
      final result = LinuxHwidProvider.formatMachineId(
        '12345678123456781234567812345678\n',
      );
      expect(result, 'CS-1234-5678');
    });

    test('should strip dashes from a dbus-style machine id', () {
      final result = LinuxHwidProvider.formatMachineId(
        '12345678-1234-5678-1234-567812345678',
      );
      expect(result, 'CS-1234-5678');
    });

    test('should return null for empty string', () {
      expect(LinuxHwidProvider.formatMachineId(''), isNull);
    });

    test('should return null for whitespace-only string', () {
      expect(LinuxHwidProvider.formatMachineId('   \n  '), isNull);
    });

    test('should return null for hex shorter than 8 chars', () {
      expect(LinuxHwidProvider.formatMachineId('a1b2c3'), isNull);
    });

    test(
      'should return null when input contains non-hex characters',
      () => expect(
        LinuxHwidProvider.formatMachineId('1234567890abcdef1234567890abcdefG'),
        isNull,
      ),
    );

    test('should return null for non-hex text', () {
      expect(LinuxHwidProvider.formatMachineId('zz-not-a-machine-id'), isNull);
    });
  });
}
