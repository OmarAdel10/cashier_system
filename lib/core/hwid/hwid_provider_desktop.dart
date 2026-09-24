// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Hardware ID provider for desktop platforms (Windows/Linux).
/// Uses conditional imports - this is the desktop implementation.
library;

import 'dart:io';
import 'package:win32_registry/win32_registry.dart';

import 'hwid_provider_interface.dart';

/// Desktop HWID provider using platform-specific APIs.
class DesktopHwidProvider implements HwidProvider {
  @override
  Future<String> getHwid() async {
    if (Platform.isWindows) {
      return _getWindowsHWID();
    } else if (Platform.isLinux) {
      return _getLinuxHWID();
    }
    return _generateFallbackHWID();
  }

  @override
  Future<Map<String, String>> getHardwareInfo() async {
    final info = <String, String>{};
    info['platform'] = Platform.operatingSystem;
    info['hostname'] = Platform.localHostname;
    info['hwid'] = await getHwid();
    return info;
  }

  @override
  bool get isAvailable => Platform.isWindows || Platform.isLinux;

  @override
  String get providerName => 'DesktopHwidProvider';

  /// Get Machine GUID from Windows registry.
  Future<String> _getWindowsHWID() async {
    try {
      // win32_registry 3.x API - use LOCAL_MACHINE predefined key
      final key = LOCAL_MACHINE.open(r'SOFTWARE\Microsoft\Cryptography');
      final value = key.getString('MachineGuid');
      key.close();
      return value?.trim() ?? _generateFallbackHWID();
    } catch (_) {
      return _generateFallbackHWID();
    }
  }

  /// Get machine ID from /etc/machine-id on Linux.
  Future<String> _getLinuxHWID() async {
    try {
      final file = File('/etc/machine-id');
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.trim();
      }
      // Fallback to D-Bus machine ID
      final dbusFile = File('/var/lib/dbus/machine-id');
      if (await dbusFile.exists()) {
        final content = await dbusFile.readAsString();
        return content.trim();
      }
    } catch (_) {}
    return _generateFallbackHWID();
  }

  /// Generate a fallback HWID based on system info.
  String _generateFallbackHWID() {
    final hostname = Platform.localHostname;
    final pid = ProcessInfo.currentRss;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return 'fallback-$hostname-$pid-$timestamp';
  }
}
