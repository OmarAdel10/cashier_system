// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'hwid_provider_interface.dart';

/// Stub HWID provider for unsupported platforms (web, macOS, etc.).
///
/// This provider always throws [HwidException] when used.
/// It exists to satisfy the conditional import system.
class StubHwidProvider implements HwidProvider {
  @override
  String get providerName => 'StubHwidProvider';

  @override
  bool get isAvailable => false;

  @override
  Future<String> getHwid() async {
    throw HwidException(
      'HWID generation is not supported on this platform',
      providerName: providerName,
    );
  }

  @override
  Future<Map<String, String>> getHardwareInfo() async {
    return {
      'error': 'HWID generation is not supported on this platform',
      'platform': 'unsupported',
    };
  }
}
