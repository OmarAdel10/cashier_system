// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Hardware ID (HWID) provider interface.
///
/// This file uses conditional imports to provide platform-specific implementations:
/// - `hwid_provider_windows.dart` for Windows (uses win32_registry + WMI)
/// - `hwid_provider_linux.dart` for Linux (uses /etc/machine-id, dmidecode, etc.)
/// - `hwid_provider_stub.dart` for unsupported platforms (web, macOS, etc.)
///
/// The correct implementation is selected at compile time based on the platform.
export 'hwid_provider_interface.dart'
    if (dart.library.io) 'hwid_provider_windows.dart'
    if (dart.library.io) 'hwid_provider_linux.dart'
    if (dart.library.html) 'hwid_provider_stub.dart';
