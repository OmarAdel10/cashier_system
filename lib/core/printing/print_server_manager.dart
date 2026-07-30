import 'dart:async';
import 'dart:developer';
import 'dart:io';

class PrintServerManager {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    try {
      final exeParent = File(Platform.resolvedExecutable).parent.path;
      final cwd = Directory.current.path;

      final candidates = <String>[
        // 1. Side-by-side with running cashier_system.exe (Highest Priority)
        [exeParent, 'PrintServer.exe'].join(Platform.pathSeparator),

        // 2. Installed production layout (Inno Setup places under PrintServer/)
        [exeParent, 'PrintServer', 'PrintServer.exe'].join(Platform.pathSeparator),

        // 3. Output folder in build/ relative to CWD
        [
          cwd,
          'build',
          'windows',
          'x64',
          'runner',
          'Debug',
          'PrintServer.exe',
        ].join(Platform.pathSeparator),
        [
          cwd,
          'build',
          'windows',
          'x64',
          'runner',
          'Release',
          'PrintServer.exe',
        ].join(Platform.pathSeparator),

        // 4. Fallback .NET bin output folder
        [
          cwd,
          'PrintServer',
          'bin',
          'Debug',
          'net8.0',
          'PrintServer.exe',
        ].join(Platform.pathSeparator),
        [
          cwd,
          'PrintServer',
          'bin',
          'Release',
          'net8.0',
          'PrintServer.exe',
        ].join(Platform.pathSeparator),
      ];

      File? targetExe;
      for (final candidate in candidates) {
        final file = File(candidate);
        if (file.existsSync()) {
          targetExe = file;
          break;
        }
      }

      if (targetExe == null) {
        log(
          '[PrintServer Error] Could not find PrintServer.exe in any candidate path.',
        );
        _isRunning = false;
        return;
      }

      // Convert to absolute paths to prevent CMD/shell relative directory bugs
      final absoluteExePath = targetExe.absolute.path;
      final workingDir = targetExe.parent.absolute.path;

      log('[PrintServer] Launching binary: $absoluteExePath');

      _process = await Process.start(
        absoluteExePath,
        [],
        workingDirectory: workingDir,
        runInShell: false, // Directly run executable without CMD shell wrapper
      );

      _isRunning = true;
      _process!.stdout.listen(
        (data) => log('[PrintServer] ${String.fromCharCodes(data)}'),
      );
      _process!.stderr.listen(
        (data) => log('[PrintServer Error] ${String.fromCharCodes(data)}'),
      );

      unawaited(
        _process!.exitCode.then((code) {
          _isRunning = false;
          log('[PrintServer] Exited with code $code');
        }),
      );
    } catch (e) {
      log('[PrintServer] Failed to start: $e');
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    if (_process != null && _isRunning) {
      _process!.kill();
      await _process!.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () => -1,
      );
      _process = null;
      _isRunning = false;
    }
  }

  void dispose() {
    stop();
  }
}
