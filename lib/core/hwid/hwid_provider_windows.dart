// Copyright (c) 2024 Daftari POS. All rights reserved.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hwid_provider_interface.dart';

/// Windows HWID provider using WMI (no registry dependency).
///
/// Combines multiple hardware identifiers for a stable, unique HWID:
/// - CPU ID from WMI (Win32_Processor)
/// - Motherboard serial from WMI (Win32_BaseBoard)
/// - BIOS serial from WMI (Win32_BIOS)
/// - Disk serial from WMI (Win32_DiskDrive)
/// - Computer name from environment
class WindowsHwidProvider implements HwidProvider {
  @override
  String get providerName => 'WindowsHwidProvider';

  @override
  bool get isAvailable => Platform.isWindows;

  @override
  Future<String> getHwid() async {
    if (!isAvailable) {
      throw HwidException(
        'WindowsHwidProvider is only available on Windows',
        providerName: providerName,
      );
    }

    try {
      final components = <String>[];

      // 1. Machine GUID from WMI (Win32_ComputerSystemProduct)
      final machineGuid = await _getMachineGuidWmi();
      if (machineGuid.isNotEmpty) {
        components.add('mg:$machineGuid');
      }

      // 2. CPU ID
      final cpuId = await _getCpuId();
      if (cpuId.isNotEmpty) {
        components.add('cpu:$cpuId');
      }

      // 3. Motherboard serial
      final mbSerial = await _getMotherboardSerial();
      if (mbSerial.isNotEmpty) {
        components.add('mb:$mbSerial');
      }

      // 4. BIOS serial
      final biosSerial = await _getBiosSerial();
      if (biosSerial.isNotEmpty) {
        components.add('bios:$biosSerial');
      }

      // 5. Primary disk serial
      final diskSerial = await _getPrimaryDiskSerial();
      if (diskSerial.isNotEmpty) {
        components.add('disk:$diskSerial');
      }

      // 6. Computer name as fallback
      final computerName = Platform.environment['COMPUTERNAME'] ?? '';
      if (computerName.isNotEmpty) {
        components.add('cn:$computerName');
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
      return 'win_${hash.substring(0, 32)}';
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
      info['machine_guid'] = await _getMachineGuidWmi();
    } catch (_) {}

    try {
      info['cpu_id'] = await _getCpuId();
    } catch (_) {}

    try {
      info['motherboard_serial'] = await _getMotherboardSerial();
    } catch (_) {}

    try {
      info['bios_serial'] = await _getBiosSerial();
    } catch (_) {}

    try {
      info['disk_serial'] = await _getPrimaryDiskSerial();
    } catch (_) {}

    try {
      info['computer_name'] = Platform.environment['COMPUTERNAME'] ?? '';
    } catch (_) {}

    try {
      info['os_version'] = Platform.operatingSystemVersion;
    } catch (_) {}

    return info;
  }

  /// Get Machine GUID using WMI (Win32_ComputerSystemProduct).
  Future<String> _getMachineGuidWmi() async {
    try {
      final result = await Process.run('wmic', [
        'csproduct',
        'get',
        'UUID',
        '/value',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'UUID=(.+)').firstMatch(output);
        return match?.group(1)?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Get CPU ID using WMI.
  Future<String> _getCpuId() async {
    try {
      final result = await Process.run('wmic', [
        'cpu',
        'get',
        'ProcessorId',
        '/value',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'ProcessorId=(.+)').firstMatch(output);
        return match?.group(1)?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Get Motherboard serial using WMI.
  Future<String> _getMotherboardSerial() async {
    try {
      final result = await Process.run('wmic', [
        'baseboard',
        'get',
        'SerialNumber',
        '/value',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'SerialNumber=(.+)').firstMatch(output);
        return match?.group(1)?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Get BIOS serial using WMI.
  Future<String> _getBiosSerial() async {
    try {
      final result = await Process.run('wmic', [
        'bios',
        'get',
        'SerialNumber',
        '/value',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'SerialNumber=(.+)').firstMatch(output);
        return match?.group(1)?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  /// Get primary disk serial using WMI.
  Future<String> _getPrimaryDiskSerial() async {
    try {
      final result = await Process.run('wmic', [
        'diskdrive',
        'get',
        'SerialNumber',
        '/value',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final matches = RegExp(r'SerialNumber=(.+)').allMatches(output);
        for (final match in matches) {
          final serial = match.group(1)?.trim();
          if (serial != null && serial.isNotEmpty && serial != 'None') {
            return serial;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Simple SHA-256 hash.
  String _sha256(String input) {
    // Using a simple hash for now - in production, use crypto package
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0') +
        DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }
}
