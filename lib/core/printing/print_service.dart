// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Print service interface with conditional imports for platform-specific implementations.
///
/// This file uses conditional imports to provide platform-specific implementations:
/// - `print_service_windows.dart` for Windows (uses .NET PrintServer sidecar)
/// - `print_service_linux.dart` for Linux (uses .NET PrintServer.Linux sidecar)
/// - `print_service_stub.dart` for unsupported platforms (web, macOS, etc.)
///
/// The correct implementation is selected at compile time based on the platform.
export 'print_service_interface.dart'
    if (dart.library.io) 'print_service_windows.dart'
    if (dart.library.io) 'print_service_linux.dart'
    if (dart.library.html) 'print_service_stub.dart';
