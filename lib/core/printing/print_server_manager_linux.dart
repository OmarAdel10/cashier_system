import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'print_server_interface.dart';

/// Linux implementation of the PrintServer sidecar manager.
/// Spawns PrintServer.Linux self-contained binary, passes --parent-pid,
/// and uses Linux-native tools (ss, ps, kill) for stale instance cleanup.
class PrintServerManagerLinux implements IPrintServerManager {
  static const String _healthEndpoint =
      'http://127.0.0.1:5150/api/printing/health';

  /// Minimum API version the sidecar must report to be usable.
  static const int requiredServerVersion = 4;

  /// Override hooks for hermetic tests (injected via constructor).
  final Future<int?> Function({Duration? timeout})? _serverVersionOverride;
  final Future<List<int>> Function()? _pidsOnPortOverride;
  final Future<bool> Function(int pid)? _isPrintServerOverride;
  final Future<void> Function(int pid)? _killOverride;
  final PrintServerProcessFactory? _processFactoryOverride;
  final List<String>? _candidatePaths;

  PrintServerManagerLinux({
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

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start() async {
    if (_isRunning) return;

    final existing = await _serverVersion();
    if (existing != null && existing >= requiredServerVersion) {
      _process = null;
      _isRunning = true;
      log(
        '[PrintServer.Linux] Adopting healthy existing instance on port 5150.',
      );
      return;
    }

    if (existing != null) {
      log(
        '[PrintServer.Linux] Existing instance on 5150 reports API version '
        '$existing (need >= $requiredServerVersion) — killing stale instance.',
      );
    }
    await _killStaleInstance();

    for (final candidate in _candidatePaths ?? exeCandidatesLinux()) {
      final file = File(candidate);
      if (!file.existsSync()) continue;

      if (!await _spawn(file)) continue;

      final version = await _waitForServerVersion(
        timeout: const Duration(seconds: 15),
      );
      if (version == null) {
        if (!_isRunning) {
          final winner = await _serverVersion();
          if (winner != null && winner >= requiredServerVersion) {
            log(
              '[PrintServer.Linux] Adopting instance started by another process.',
            );
            _process = null;
            _isRunning = true;
            return;
          }
          _process = null;
          continue;
        }
        log(
          '[PrintServer.Linux Error] Instance did not become healthy within 15s.',
        );
        return;
      }

      if (version >= requiredServerVersion) return;

      log(
        '[PrintServer.Linux] Launched binary reports API version $version '
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
    }

    log('[PrintServer.Linux Error] No usable PrintServer.Linux found.');
    _isRunning = false;
    _process = null;
  }

  @override
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

  @override
  void dispose() {
    stop();
  }

  @override
  Future<bool> isHealthy() async {
    final version = await _serverVersion();
    return version != null && version >= requiredServerVersion;
  }

  /// Candidate locations for the PrintServer.Linux executable, in priority order.
  static List<String> exeCandidatesLinux() {
    final exeParent = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;

    return [
      // 1. Side-by-side with running cashier_system (AppImage extracts here)
      [
        exeParent,
        'PrintServer',
        'PrintServer.Linux',
      ].join(Platform.pathSeparator),

      // 2. Installed RPM layout: /opt/cashier-system/PrintServer/PrintServer.Linux
      '/opt/cashier-system/PrintServer/PrintServer.Linux',

      // 3. AppImage bundle: extracted resources next to binary
      [
        exeParent,
        '..',
        'PrintServer',
        'PrintServer.Linux',
      ].join(Platform.pathSeparator),

      // 4. Dev layout: published output in build/
      [
        cwd,
        'build',
        'linux',
        'x64',
        'release',
        'bundle',
        'PrintServer',
        'PrintServer.Linux',
      ].join(Platform.pathSeparator),

      // 5. Fallback: PrintServer.Linux project output
      [
        cwd,
        'PrintServer.Linux',
        'bin',
        'Release',
        'net8.0',
        'linux-x64',
        'PrintServer.Linux',
      ].join(Platform.pathSeparator),
      [
        cwd,
        'PrintServer.Linux',
        'bin',
        'Debug',
        'net8.0',
        'linux-x64',
        'PrintServer.Linux',
      ].join(Platform.pathSeparator),
    ];
  }

  /// Starts [file] as the PrintServer.Linux child and wires stdout/stderr/exit
  /// listeners. Returns true when the process was launched.
  Future<bool> _spawn(File file) async {
    final absoluteExePath = file.absolute.path;
    final workingDir = file.parent.absolute.path;

    log('[PrintServer.Linux] Launching binary: $absoluteExePath');

    try {
      // Ensure executable bit
      await Process.run('chmod', ['+x', absoluteExePath]);

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
              runInShell: false,
              environment: {
                ...Platform.environment,
                'DOTNET_hostBuilder:reloadConfigOnChange': 'false',
                'ASPNETCORE_URLS': 'http://127.0.0.1:5150',
              },
            );

      _process = process;
      _isRunning = true;
      process.stdout.listen(
        (data) => log('[PrintServer.Linux] ${String.fromCharCodes(data)}'),
      );
      process.stderr.listen(
        (data) =>
            log('[PrintServer.Linux Error] ${String.fromCharCodes(data)}'),
      );

      unawaited(
        process.exitCode.then((code) {
          _isRunning = false;
          log('[PrintServer.Linux] Exited with code $code');
        }),
      );
      return true;
    } catch (e) {
      log('[PrintServer.Linux] Failed to start: $e');
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

  /// Kills any PrintServer.Linux still listening on port 5150 (a stale instance
  /// from a crashed previous run that is no longer answering).
  Future<void> _killStaleInstance() async {
    if (_pidsOnPortOverride == null && !Platform.isLinux) return;

    final List<int> pids;
    try {
      pids = _pidsOnPortOverride != null
          ? await _pidsOnPortOverride()
          : await _pidsListeningOnPort5150();
    } catch (e) {
      log('[PrintServer.Linux] Could not inspect port 5150: $e');
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
          '[PrintServer.Linux] Killing stale instance (PID $processPid) holding port 5150.',
        );
        if (_killOverride != null) {
          await _killOverride(processPid);
        } else {
          await Process.run('kill', ['-TERM', '$processPid']);
          await Future.delayed(const Duration(milliseconds: 500));
          final stillAlive = await Process.run('ps', [
            '-p',
            '$processPid',
            '-o',
            'pid=',
          ]);
          if (stillAlive.stdout.toString().trim().isNotEmpty) {
            await Process.run('kill', ['-KILL', '$processPid']);
          }
        }
      } catch (e) {
        log('[PrintServer.Linux] Failed to kill stale PID $processPid: $e');
      }
    }
  }

  /// Returns true when the given PID belongs to PrintServer.Linux (via ps).
  Future<bool> _isPrintServerProcess(int processPid) async {
    final check = await Process.run('ps', ['-p', '$processPid', '-o', 'comm=']);
    final comm = check.stdout.toString().trim();
    return comm.contains('PrintServer.Linux');
  }

  /// Returns PIDs of processes listening on TCP port 5150 (via ss).
  Future<List<int>> _pidsListeningOnPort5150() async {
    final result = await Process.run('ss', ['-ltnp', 'sport = :5150']);
    final pids = <int>{};
    for (final line in result.stdout.toString().split('\n')) {
      if (!line.contains(':5150') || !line.contains('LISTEN')) continue;
      // Parse PID from: users:(("PrintServer.Linux",pid=12345,fd=6))
      final match = RegExp(r'pid=(\d+)').firstMatch(line);
      if (match != null) {
        pids.add(int.parse(match.group(1)!));
      }
    }
    return pids.toList();
  }
}

/// Process factory typedef (shared with Windows implementation for testability).
typedef PrintServerProcessFactory =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      bool? runInShell,
    });
