// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'dart:io';

import 'package:http/http.dart' as http;

import 'print_service_interface.dart';
import 'print_service_windows.dart';
import 'print_service_linux.dart';
import 'print_service_stub.dart';

/// Factory for creating platform-specific PrintService instances.
///
/// This factory selects the correct implementation at runtime based on the platform.
class PrintServiceFactory {
  /// Create a PrintService instance for the current platform.
  ///
  /// [baseUrl] - Optional base URL for the PrintServer API.
  /// [client] - Optional HTTP client for testing.
  static PrintService create({String? baseUrl, http.Client? client}) {
    if (Platform.isWindows) {
      return WindowsPrintService(baseUrl: baseUrl, client: client);
    } else if (Platform.isLinux) {
      return LinuxPrintService(baseUrl: baseUrl, client: client);
    } else {
      return StubPrintService();
    }
  }

  /// Create a PrintService with explicit platform selection (for testing).
  static PrintService createForPlatform(
    TargetPlatform platform, {
    String? baseUrl,
    http.Client? client,
  }) {
    switch (platform) {
      case TargetPlatform.windows:
        return WindowsPrintService(baseUrl: baseUrl, client: client);
      case TargetPlatform.linux:
        return LinuxPrintService(baseUrl: baseUrl, client: client);
      default:
        return StubPrintService();
    }
  }
}

/// Enum for target platforms (used in testing).
enum TargetPlatform { windows, linux, macos, android, ios, web, fuchsia }
