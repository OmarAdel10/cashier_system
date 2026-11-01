// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Print Service with conditional imports for platform-specific implementations.
///
/// This file uses conditional imports to provide platform-specific print
/// implementations:
/// - `print_service_desktop.dart` for Windows/Linux (dart:io)
/// - `print_service_web.dart` for web (dart:html)
/// - `print_service_stub.dart` for fallback (unsupported platforms)
library;

export 'print_service_stub.dart';
export 'print_service_desktop.dart'
    if (dart.library.io) 'print_service_desktop.dart';
export 'print_service_web.dart' if (dart.library.html) 'print_service_web.dart';
