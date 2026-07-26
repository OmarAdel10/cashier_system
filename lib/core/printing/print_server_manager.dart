import 'dart:async';
import 'dart:io';

class PrintServerManager {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    try {
      final candidates = <String>[
        'PrintServer${Platform.pathSeparator}PrintServer.exe',
        'PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Debug${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        'PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Release${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
      ];
      final exePath = candidates.firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => candidates.first,
      );
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: 'PrintServer',
        runInShell: true,
      );
      _isRunning = true;
      _process!.stdout.listen((data) => print('[PrintServer] ${String.fromCharCodes(data)}'));
      _process!.stderr.listen((data) => print('[PrintServer Error] ${String.fromCharCodes(data)}'));
      unawaited(_process!.exitCode.then((code) {
        _isRunning = false;
        print('[PrintServer] Exited with code $code');
      }));
    } catch (e) {
      print('[PrintServer] Failed to start: $e');
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    if (_process != null && _isRunning) {
      _process!.kill();
      await _process!.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1);
      _process = null;
      _isRunning = false;
    }
  }

  void dispose() {
    stop();
  }
}
