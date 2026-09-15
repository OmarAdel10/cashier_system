// Copyright (c) 2024 Daftari POS. All rights reserved.

/// HWID Provider with conditional imports for platform-specific implementations.
///
/// This file uses conditional imports to provide platform-specific HWID
/// implementations:
/// - `hwid_provider_desktop.dart` for Windows/Linux (dart:io)
/// - `hwid_provider_web.dart` for web (dart:html)
/// - `hwid_provider_stub.dart` for fallback (unsupported platforms)

export 'hwid_provider_stub.dart';
export 'hwid_provider_desktop.dart'
    if (dart.library.io) 'hwid_provider_desktop.dart';
export 'hwid_provider_web.dart' if (dart.library.html) 'hwid_provider_web.dart';
