import 'dart:async';
import 'dart:developer';
import 'dart:io';

class PrintServerManager {
  static const String _healthEndpoint =
      'http://127.0.0.1:5150/api/printing/health';
  static const String _exeName = 'PrintServer.exe';

  /// Override hooks for hermetic tests (injected via constructor).
  final Future<bool> Function({Duration? timeout})? _healthCheckOverride;
  final Future<List<int>> Function()? _pidsOnPortOverride;
  final Future<bool> Function(int pid)? _isPrintServerOverride;
  final Future<void> Function(int pid)? _killOverride;
  final List<String>? _candidatePaths;

  PrintServerManager({
    Future<bool> Function({Duration? timeout})? healthCheck,
    Future<List<int>> Function()? pidsOnPort,
    Future<bool> Function(int pid)? isPrintServer,
    Future<void> Function(int pid)? killProcess,
    List<String>? candidatePaths,
  }) : _healthCheckOverride = healthCheck,
       _pidsOnPortOverride = pidsOnPort,
       _isPrintServerOverride = isPrintServer,
       _killOverride = killProcess,
       _candidatePaths = candidatePaths;

  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    // 1. A healthy instance is already serving port 5150 (e.g. another app
    //    instance or a leftover that still works): adopt it instead of
    //    spawning a competing copy. stop() will not kill a shared server.
    if (await _isHealthy()) {
      _process = null;
      _isRunning = true;
      log('[PrintServer] Adopting healthy existing instance on port 5150.');
      return;
    }

    // 2. Port occupied but unresponsive -> stale/crashed instance from a
    //    previous run. Kill it so our fresh instance can bind the port.
    await _killStaleInstance();

    // 3. Locate the executable and launch our own instance.
    final targetExe = _findExecutable();
    if (targetExe == null) {
      log(
        '[PrintServer Error] Could not find PrintServer.exe in any candidate path.',
      );
      _isRunning = false;
      return;
    }

    final absoluteExePath = targetExe.absolute.path;
    final workingDir = targetExe.parent.absolute.path;

    log('[PrintServer] Launching binary: $absoluteExePath');

    try {
      _process = await Process.start(
        absoluteExePath,
        [
          // Make the server self-terminate if this app crashes or closes.
          '--parent-pid',
          '$pid',
        ],
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
      _process = null;
      _isRunning = false;
    }

    // 4. Wait until our instance actually serves HTTP before returning, so
    //    the first print never races the server boot. If our child dies but
    //    the port becomes healthy (a concurrent launch won), adopt that one.
    final ready = await _waitUntilHealthy(timeout: const Duration(seconds: 15));
    if (!ready) {
      log('[PrintServer Error] Instance did not become healthy within 15s.');
    } else if (!_isRunning) {
      // The child we spawned exited but the port answers — a concurrent
      // instance won the port; adopt it so stop() never kills a shared server.
      log('[PrintServer] Adopting instance started by another process.');
      _process = null;
      _isRunning = true;
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

  /// Candidate locations for the PrintServer executable, in priority order.
  /// Shared with main.dart's publish decision so "already installed" is
  /// detected for every layout (dev build, side-by-side, Inno Setup install).
  static List<String> exeCandidates() {
    final exeParent = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;

    return [
      // 1. Side-by-side with running cashier_system.exe (Highest Priority)
      [exeParent, _exeName].join(Platform.pathSeparator),

      // 2. Installed production layout (Inno Setup places under PrintServer/)
      [exeParent, 'PrintServer', _exeName].join(Platform.pathSeparator),

      // 3. Output folder in build/ relative to CWD
      [
        cwd,
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
        _exeName,
      ].join(Platform.pathSeparator),
      [
        cwd,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        _exeName,
      ].join(Platform.pathSeparator),

      // 4. Fallback .NET bin output folder
      [
        cwd,
        'PrintServer',
        'bin',
        'Debug',
        'net8.0',
        _exeName,
      ].join(Platform.pathSeparator),
      [
        cwd,
        'PrintServer',
        'bin',
        'Release',
        'net8.0',
        _exeName,
      ].join(Platform.pathSeparator),
    ];
  }

  File? _findExecutable() {
    for (final candidate in _candidatePaths ?? exeCandidates()) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// True when something answers on the PrintServer health endpoint.
  Future<bool> _isHealthy({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final override = _healthCheckOverride;
    if (override != null) return override(timeout: timeout);

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(_healthEndpoint));
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Polls the health endpoint until it answers or [timeout] elapses.
  Future<bool> _waitUntilHealthy({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isHealthy(timeout: const Duration(seconds: 1))) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return await _isHealthy(timeout: const Duration(seconds: 1));
  }

  /// Kills any PrintServer.exe still listening on port 5150 (a stale instance
  /// from a crashed previous run that is no longer answering). Never touches
  /// unrelated processes. No-op on non-Windows platforms.
  Future<void> _killStaleInstance() async {
    if (_pidsOnPortOverride == null && !Platform.isWindows) return;

    final List<int> pids;
    try {
      pids = _pidsOnPortOverride != null
          ? await _pidsOnPortOverride()
          : await _pidsListeningOnPort5150();
    } catch (e) {
      log('[PrintServer] Could not inspect port 5150: $e');
      return;
    }
    if (pids.isEmpty) return;

    for (final processPid in pids) {
      try {
        final isPrintServer = _isPrintServerOverride != null
            ? await _isPrintServerOverride(processPid)
            : await _isPrintServerProcess(processPid);
        if (!isPrintServer) continue;

        log(
          '[PrintServer] Killing stale instance (PID $processPid) holding port 5150.',
        );
        if (_killOverride != null) {
          await _killOverride(processPid);
        } else {
          await Process.run('taskkill', ['/F', '/PID', '$processPid', '/T']);
        }
      } catch (e) {
        log('[PrintServer] Failed to kill stale PID $processPid: $e');
      }
    }
  }

  /// Returns true when the given PID belongs to PrintServer.exe (via tasklist).
  Future<bool> _isPrintServerProcess(int processPid) async {
    final check = await Process.run('tasklist', [
      '/FI',
      'PID eq $processPid',
      '/FO',
      'CSV',
      '/NH',
    ]);
    return check.stdout.toString().contains(_exeName);
  }

  /// Returns PIDs of processes listening on TCP port 5150 (via netstat).
  Future<List<int>> _pidsListeningOnPort5150() async {
    final result = await Process.run('netstat', ['-ano', '-p', 'tcp']);
    final pids = <int>{};
    for (final rawLine in result.stdout.toString().split('\n')) {
      final line = rawLine.trim();
      if (!line.contains(':5150') || !line.contains('LISTENING')) continue;
      final tokens = line.split(RegExp(r'\s+'));
      final last = tokens.isEmpty ? '' : tokens.last;
      final pid = int.tryParse(last);
      if (pid != null) pids.add(pid);
    }
    return pids.toList();
  }
}
