import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

/// Launches the PrintServer sidecar process (hermetic-test override hook).
typedef PrintServerProcessFactory =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      bool? runInShell,
    });

class PrintServerManager {
  static const String _healthEndpoint =
      'http://127.0.0.1:5150/api/printing/health';
  static const String _exeName = 'PrintServer.exe';

  /// Minimum API version the sidecar must report to be usable. Older binaries must be replaced.
  static const int requiredServerVersion = 4;

  /// Override hooks for hermetic tests (injected via constructor).
  final Future<int?> Function({Duration? timeout})? _serverVersionOverride;
  final Future<List<int>> Function()? _pidsOnPortOverride;
  final Future<bool> Function(int pid)? _isPrintServerOverride;
  final Future<void> Function(int pid)? _killOverride;
  final PrintServerProcessFactory? _processFactoryOverride;
  final List<String>? _candidatePaths;

  PrintServerManager({
    Future<int?> Function({Duration? timeout})? serverVersion,
    Future<List<int>> Function()? pidsOnPort,
    Future<bool> Function(int pid)? isPrintServer,
    Future<void> Function(int pid)? killProcess,
    PrintServerProcessFactory? processFactory,
    List<String>? candidatePaths,
  }) : _serverVersionOverride = serverVersion,
       _pidsOnPortOverride = pidsOnPort,
       _isPrintServerOverride = isPrintServer,
       _killOverride = killProcess,
       _processFactoryOverride = processFactory,
       _candidatePaths = candidatePaths;

  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    final existing = await _serverVersion();
    if (existing != null && existing >= requiredServerVersion) {
      _process = null;
      _isRunning = true;
      log('[PrintServer] Adopting healthy existing instance on port 5150.');
      return;
    }

    if (existing != null) {
      log(
        '[PrintServer] Existing instance on 5150 reports API version '
        '$existing (need >= $requiredServerVersion) — killing stale instance.',
      );
    }
    await _killStaleInstance();

    // 3. Locate the executable and launch our own instance.
    for (final candidate in _candidatePaths ?? exeCandidates()) {
      final file = File(candidate);
      if (!file.existsSync()) continue;

      if (!await _spawn(file)) continue;

      // 4. Wait until our instance actually serves HTTP before returning, so
      //    the first print never races the server boot.
      final version = await _waitForServerVersion(
        timeout: const Duration(seconds: 15),
      );
      if (version == null) {
        if (!_isRunning) {
          // The child we spawned exited — maybe a concurrent instance won the
          // port; adopt it so stop() never kills a shared server.
          final winner = await _serverVersion();
          if (winner != null && winner >= requiredServerVersion) {
            log('[PrintServer] Adopting instance started by another process.');
            _process = null;
            _isRunning = true;
            return;
          }
          _process = null;
          continue; // try next candidate
        }
        log('[PrintServer Error] Instance did not become healthy within 15s.');
        return;
      }

      if (version >= requiredServerVersion) return; // success

      log(
        '[PrintServer] Launched binary reports API version $version '
        '(need >= $requiredServerVersion) — stale build, trying next candidate.',
      );
      final child = _process;
      if (child != null) {
        child.kill();
        await child.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () => -1,
        );
      }
      _process = null;
      continue;
    }

    log('[PrintServer Error] No usable PrintServer.exe found.');
    _isRunning = false;
    _process = null;
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

  /// Starts [file] as the PrintServer child and wires stdout/stderr/exit
  /// listeners. Returns true when the process was launched.
  Future<bool> _spawn(File file) async {
    final absoluteExePath = file.absolute.path;
    final workingDir = file.parent.absolute.path;

    log('[PrintServer] Launching binary: $absoluteExePath');

    try {
      // Make the server self-terminate if this app crashes or closes.
      final args = ['--parent-pid', '$pid'];

      final factory = _processFactoryOverride;
      final process = factory != null
          ? await factory(
              absoluteExePath,
              args,
              workingDirectory: workingDir,
              runInShell: false,
            )
          : await Process.start(
              absoluteExePath,
              args,
              workingDirectory: workingDir,
              runInShell:
                  false, // Directly run executable without CMD shell wrapper
            );

      _process = process;
      _isRunning = true;
      process.stdout.listen(
        (data) => log('[PrintServer] ${String.fromCharCodes(data)}'),
      );
      process.stderr.listen(
        (data) => log('[PrintServer Error] ${String.fromCharCodes(data)}'),
      );

      unawaited(
        process.exitCode.then((code) {
          _isRunning = false;
          log('[PrintServer] Exited with code $code');
        }),
      );
      return true;
    } catch (e) {
      log('[PrintServer] Failed to start: $e');
      _process = null;
      _isRunning = false;
      return false;
    }
  }

  /// Reports the integer API version from GET /api/printing/health, or null
  /// when the endpoint is unreachable, unhealthy, or the body does not parse.
  Future<int?> _serverVersion({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final override = _serverVersionOverride;
    if (override != null) return override(timeout: timeout);

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(_healthEndpoint));
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['version'] as int?;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Polls [_serverVersion] every 250ms until a version is reported or
  /// [timeout] elapses (returns the last reported version, or null).
  Future<int?> _waitForServerVersion({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    int? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await _serverVersion(timeout: const Duration(seconds: 1));
      if (last != null) return last;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return last;
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
