// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'hwid_provider_stub.dart';

/// Web HWID provider using browser fingerprinting.
class HwidProviderWeb implements HwidProvider {
  @override
  String getHardwareId() {
    // In a real implementation, this would use browser fingerprinting
    // For now, return a stub with timestamp
    return 'CS-WEB-${DateTime.now().millisecondsSinceEpoch}';
  }
}
