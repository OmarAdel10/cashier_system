// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Interface for Hardware ID (HWID) providers.
///
/// Each platform implements this interface to provide a unique,
/// stable hardware identifier for licensing and device identification.
abstract interface class HwidProvider {
  /// Get the hardware ID for this device.
  ///
  /// Returns a unique, stable identifier string that can be used
  /// for license binding and device tracking.
  ///
  /// Throws [HwidException] if the HWID cannot be determined.
  Future<String> getHwid();

  /// Get additional hardware information for debugging.
  ///
  /// Returns a map of hardware properties (CPU, motherboard, BIOS, etc.)
  /// that can be used for support and diagnostics.
  Future<Map<String, String>> getHardwareInfo();

  /// Check if the HWID provider is available on this platform.
  bool get isAvailable;

  /// Provider name/identifier.
  String get providerName;
}

/// Exception thrown when HWID operations fail.
class HwidException implements Exception {
  final String message;
  final String? providerName;
  final Object? originalError;
  final StackTrace? stackTrace;

  const HwidException(
    this.message, {
    this.providerName,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('HwidException');
    if (providerName != null) {
      buffer.write(' ($providerName)');
    }
    buffer.write(': $message');
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    return buffer.toString();
  }
}
