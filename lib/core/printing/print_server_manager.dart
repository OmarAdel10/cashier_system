import 'dart:async';
import 'dart:io';

class PrintServerManager {
  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    try {
      final cwd = Directory.current.path;
      final exeDir = Platform.resolvedExecutable;
      final exeParent = File(exeDir).parent.path;

      final candidates = <String>[
        // Relative to CWD
        'PrintServer${Platform.pathSeparator}PrintServer.exe',
        'PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Debug${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        'PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Release${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        // Absolute from CWD
        '$cwd${Platform.pathSeparator}PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Debug${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        '$cwd${Platform.pathSeparator}PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Release${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        // Relative to executable directory
        '$exeParent${Platform.pathSeparator}..${Platform.pathSeparator}PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Debug${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        '$exeParent${Platform.pathSeparator}..${Platform.pathSeparator}PrintServer${Platform.pathSeparator}bin${Platform.pathSeparator}Release${Platform.pathSeparator}net8.0${Platform.pathSeparator}PrintServer.exe',
        // Side-by-side with executable
        '$exeParent${Platform.pathSeparator}PrintServer.exe',
        // Flutter Windows build output (dotnet publish output)
        'build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Debug${Platform.pathSeparator}PrintServer.exe',
        'build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Release${Platform.pathSeparator}PrintServer.exe',
        '$cwd${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Debug${Platform.pathSeparator}PrintServer.exe',
        '$cwd${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Release${Platform.pathSeparator}PrintServer.exe',
      ];
      final exePath = candidates.firstWhere(
        (p) => File(p).existsSync(),
        orElse: () => candidates.first,
      );

      // Determine working directory: parent of exe or PrintServer folder
      final exeFile = File(exePath);
      String workingDir;
      if (exeFile.existsSync()) {
        workingDir = exeFile.parent.path;
      } else {
        workingDir = 'PrintServer';
      }

      _process = await Process.start(
        exePath,
        [],
        workingDirectory: workingDir,
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
