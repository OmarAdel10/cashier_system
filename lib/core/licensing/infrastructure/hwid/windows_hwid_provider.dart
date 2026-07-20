import 'dart:io';

import 'hwid_provider.dart';

class WindowsHwidProvider implements HwidProvider {
  static final _guidPattern = RegExp(r'\{?([0-9A-Fa-f\-]{36})\}?');

  @override
  Future<String?> getHardwareId() async {
    try {
      final result = await Process.run(
        'reg',
        [
          'QUERY',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ],
      );
      if (result.exitCode != 0) return null;
      final output = result.stdout as String;
      final match = _guidPattern.firstMatch(output);
      if (match == null) return null;
      final guid = match.group(1)!.replaceAll('-', '');
      if (guid.length < 8) return null;
      final tail = guid.substring(guid.length - 8).toUpperCase();
      return 'CS-${tail.substring(0, 4)}-${tail.substring(4)}';
    } catch (_) {
      return null;
    }
  }
}
