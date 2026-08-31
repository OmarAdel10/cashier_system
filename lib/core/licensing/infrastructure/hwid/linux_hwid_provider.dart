import 'dart:io';

import 'hwid_provider.dart';

/// Resolves a stable hardware identifier on Linux by reading the
/// systemd machine-id file (populated on virtually every modern
/// distribution), falling back to the D-Bus machine-id.
///
/// The resulting ID is formatted identically to [WindowsHwidProvider]
/// (`CS-XXXX-XXXX`) so the activation-key signing pipeline is
/// platform-agnostic.
class LinuxHwidProvider implements HwidProvider {
  static const _machineIdPaths = [
    '/etc/machine-id',
    '/var/lib/dbus/machine-id',
  ];

  static final _hexPattern = RegExp(r'^[0-9A-Fa-f]+$');

  /// Extracts the last 8 hex characters of a machine-id and formats
  /// them as `CS-XXXX-XXXX`. Returns null for empty or non-hex input.
  static String? formatMachineId(String rawOutput) {
    final hex = rawOutput.trim().replaceAll('-', '');
    if (hex.length < 8 || !_hexPattern.hasMatch(hex)) return null;
    final tail = hex.substring(hex.length - 8).toUpperCase();
    return 'CS-${tail.substring(0, 4)}-${tail.substring(4)}';
  }

  @override
  Future<String?> getHardwareId() async {
    for (final path in _machineIdPaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final id = formatMachineId(await file.readAsString());
        if (id != null) return id;
      } catch (_) {
        // Unreadable file — try the next candidate path.
      }
    }
    return null;
  }
}
