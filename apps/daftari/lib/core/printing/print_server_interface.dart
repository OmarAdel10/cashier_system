/// Platform-agnostic contract for PrintServer sidecar lifecycle management.
/// Implemented by [PrintServerManager] (Windows) and [PrintServerManagerLinux] (Linux).
abstract class IPrintServerManager {
  /// Starts the PrintServer sidecar process if not already running.
  /// Returns when the server reports healthy on /api/printing/health.
  Future<void> start();

  /// Stops the sidecar process if this instance launched it.
  /// Does not kill adopted instances.
  Future<void> stop();

  /// Checks if the sidecar is currently running and healthy.
  Future<bool> isHealthy();

  /// Releases resources. Calls [stop] if this instance owns the process.
  void dispose();

  /// Current running state (for UI indicators).
  bool get isRunning;
}
