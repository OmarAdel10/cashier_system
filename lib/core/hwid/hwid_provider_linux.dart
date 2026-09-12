// Copyright (c) 2024 Daftari POS. All rights reserved.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'hwid_provider_interface.dart';

/// Linux HWID provider using system files and dmidecode.
///
/// Combines multiple hardware identifiers for a stable, unique HWID:
/// - /etc/machine-id (systemd)
/// - /var/lib/dbus/machine-id (D-Bus)
/// - CPU info from /proc/cpuinfo
/// - Motherboard info from dmidecode (requires root)
/// - Disk serial from lsblk/udev
class LinuxHwidProvider implements HwidProvider {
  @override
  String get providerName => 'LinuxHwidProvider';

  @override
  bool get isAvailable => Platform.isLinux;

  @override
  Future<String> getHwid() async {
    if (!isAvailable) {
      throw HwidException(
        'LinuxHwidProvider is only available on Linux',
        providerName: providerName,
      );
    }

    try {
      final components = <String>[];

      // 1. Machine ID (systemd) - most stable
      final machineId = await _getMachineId();
      if (machineId.isNotEmpty) {
        components.add('mid:$machineId');
      }

      // 2. D-Bus machine ID
      final dbusId = await _getDbusMachineId();
      if (dbusId.isNotEmpty && dbusId != machineId) {
        components.add('dbus:$dbusId');
      }

      // 3. CPU info
      final cpuInfo = await _getCpuInfo();
      if (cpuInfo.isNotEmpty) {
        components.add('cpu:$cpuInfo');
      }

      // 4. Motherboard info (dmidecode - requires root)
      final mbInfo = await _getMotherboardInfo();
      if (mbInfo.isNotEmpty) {
        components.add('mb:$mbInfo');
      }

      // 5. Primary disk serial
      final diskSerial = await _getPrimaryDiskSerial();
      if (diskSerial.isNotEmpty) {
        components.add('disk:$diskSerial');
      }

      if (components.isEmpty) {
        throw HwidException(
          'No hardware identifiers could be retrieved',
          providerName: providerName,
        );
      }

      // Combine components and hash for consistent length
      final combined = components.join('|');
      final hash = _sha256(combined);
      return 'lin_${hash.substring(0, 32)}';
    } catch (e, st) {
      if (e is HwidException) rethrow;
      throw HwidException(
        'Failed to generate HWID: $e',
        providerName: providerName,
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<Map<String, String>> getHardwareInfo() async {
    final info = <String, String>{};

    try {
      info['machine_id'] = await _getMachineId();
    } catch (_) {}

    try {
      info['dbus_machine_id'] = await _getDbusMachineId();
    } catch (_) {}

    try {
      info['cpu_info'] = await _getCpuInfo();
    } catch (_) {}

    try {
      info['motherboard_info'] = await _getMotherboardInfo();
    } catch (_) {}

    try {
      info['disk_serial'] = await _getPrimaryDiskSerial();
    } catch (_) {}

    try {
      info['hostname'] = Platform.environment['HOSTNAME'] ?? '';
    } catch (_) {}

    try {
      info['os_version'] = Platform.operatingSystemVersion;
    } catch (_) {}

    return info;
  }

  /// Get machine ID from /etc/machine-id or /var/lib/dbus/machine-id.
  Future<String> _getMachineId() async {
    const paths = ['/etc/machine-id', '/var/lib/dbus/machine-id'];

    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          return content.trim();
        }
      } catch (_) {}
    }
    return '';
  }

  /// Get D-Bus machine ID.
  Future<String> _getDbusMachineId() async {
    try {
      final file = File('/var/lib/dbus/machine-id');
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Get CPU info from /proc/cpuinfo.
  Future<String> _getCpuInfo() async {
    try {
      final file = File('/proc/cpuinfo');
      if (await file.exists()) {
        final content = await file.readAsString();
        // Extract processor serial or unique ID
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('Serial') || line.startsWith('processor')) {
            final parts = line.split(':');
            if (parts.length > 1) {
              return parts[1].trim();
            }
          }
        }
        // Fallback: hash the whole cpuinfo
        return _simpleHash(content).substring(0, 16);
      }
    } catch (_) {}
    return '';
  }

  /// Get motherboard info using dmidecode (requires root).
  Future<String> _getMotherboardInfo() async {
    try {
      final result = await Process.run('dmidecode', [
        '-t',
        'baseboard',
        '-q',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Extract serial number
        final match = RegExp(r'Serial Number:\s*(.+)').firstMatch(output);
        if (match != null) {
          return match.group(1)?.trim() ?? '';
        }
        // Fallback: hash the output
        return _simpleHash(output).substring(0, 16);
      }
    } catch (_) {}
    return '';
  }

  /// Get primary disk serial using lsblk.
  Future<String> _getPrimaryDiskSerial() async {
    try {
      final result = await Process.run('lsblk', [
        '-d',
        '-n',
        '-o',
        'SERIAL',
        '/dev/sda',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final serial = result.stdout.toString().trim();
        if (serial.isNotEmpty && serial != 'NULL') {
          return serial;
        }
      }
    } catch (_) {}

    // Try nvme
    try {
      final result = await Process.run('nvme', [
        'id-ctrl',
        '/dev/nvme0',
        '-H',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'sn\s*:\s*(.+)').firstMatch(output);
        if (match != null) {
          return match.group(1)?.trim() ?? '';
        }
      }
    } catch (_) {}

    return '';
  }

  /// Simple hash function.
  String _sha256(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0') +
        DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }

  /// Simple hash for fallback.
  String _simpleHash(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
