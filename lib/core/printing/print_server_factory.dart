import 'dart:io';

import 'print_server_interface.dart';
import 'print_server_manager.dart';
import 'print_server_manager_linux.dart';

/// Platform-aware factory for PrintServer manager.
/// Called once in main.dart during startup.
class PrintServerFactory {
  static IPrintServerManager create() {
    if (Platform.isWindows) {
      return PrintServerManager(); // Existing implementation
    } else if (Platform.isLinux) {
      return PrintServerManagerLinux(); // New implementation
    } else {
      // macOS, etc. - return no-op for now
      return _NoOpPrintServerManager();
    }
  }
}

/// No-op for unsupported platforms (macOS, etc.)
class _NoOpPrintServerManager implements IPrintServerManager {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isHealthy() async => false;

  @override
  void dispose() {}

  @override
  bool get isRunning => false;
}
