import 'dart:io';

import 'hwid_provider.dart';

class WindowsHwidProvider implements HwidProvider {
  static final _guidPattern = RegExp(r'\{?([0-9A-Fa-f\-]{36})\}?');

  static String? formatGuid(String rawOutput) {
    final match = _guidPattern.firstMatch(rawOutput);
    if (match == null) return null;
    final guid = match.group(1)!.replaceAll('-', '');
    if (guid.length < 8) return null;
    final tail = guid.substring(guid.length - 8).toUpperCase();
    return 'CS-${tail.substring(0, 4)}-${tail.substring(4)}';
  }

  @override
  Future<String?> getHardwareId() async {
    try {
      final result = await Process.run('reg', [
        'QUERY',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
      ]);
      if (result.exitCode != 0) return null;
      return formatGuid(result.stdout as String);
    } catch (_) {
      return null;
    }
  }
}
