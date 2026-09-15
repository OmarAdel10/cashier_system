// Copyright (c) 2024 Daftari POS. All rights reserved.

/// HWID Provider stub for unsupported platforms.
abstract class HwidProvider {
  /// Returns a hardware identifier for the current device.
  String getHardwareId();
}

/// Stub implementation for unsupported platforms.
class HwidProviderStub implements HwidProvider {
  @override
  String getHardwareId() => 'CS-STUB-${DateTime.now().millisecondsSinceEpoch}';
}
