import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_server_manager.dart';

/// A fake Process that simulates the PrintServer process.
class FakeProcess implements Process {
  @override
  int get pid => 12345;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _stdinSink;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>.broadcast();
  final _stdinSink = _FakeIOSink();
  final Completer<int> _exitCodeCompleter = Completer<int>();

  bool _killed = false;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(0);
    }
    return true;
  }

  bool get wasKilled => _killed;

  void simulateExit(int code) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }

  void dispose() {
    _stdoutController.close();
    _stderrController.close();
  }
}

class _FakeIOSink implements IOSink {
  @override
  void add(List<int> data) {}
  @override
  void write(Object? object) {}
  @override
  void writeln([Object? object = '']) {}
  @override
  void writeAll(Iterable objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => Future.value();
  @override
  Future<void> flush() => Future.value();
  @override
  Future<void> close() => Future.value();
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding encoding) {}
  @override
  Future<void> get done => Future.value();
}

void main() {
  late PrintServerManager manager;

  Directory? tempDir;
  late String exePath;
  late String secondExePath;

  setUp(() {
    manager = PrintServerManager();
    tempDir = Directory.systemTemp.createTempSync('print_server_manager_test');
    exePath = '${tempDir!.path}${Platform.pathSeparator}PrintServer.exe';
    secondExePath =
        '${tempDir!.path}${Platform.pathSeparator}PrintServer-2.exe';
    File(exePath).createSync();
    File(secondExePath).createSync();
  });

  tearDown(() {
    manager.dispose();
    tempDir?.deleteSync(recursive: true);
  });

  group('PrintServerManager', () {
    test('isRunning returns false initially', () {
      expect(manager.isRunning, false);
    });

    test('stop — when not running, does nothing', () async {
      await manager.stop();
      expect(manager.isRunning, false);
    });

    test('dispose — delegates to stop', () async {
      manager.dispose();
      expect(manager.isRunning, false);
    });

    test('start — already running is no-op', () async {
      var versionCalls = 0;
      final running = PrintServerManager(
        serverVersion: ({timeout}) async {
          versionCalls++;
          return 4;
        },
      );

      await running.start();
      expect(running.isRunning, true);
      expect(versionCalls, 1);

      await running.start();
      expect(versionCalls, 1, reason: 'second start while running is a no-op');
    });
  });

  group('PrintServerManager adoption', () {
    test(
      'adopts a healthy current-version instance without spawning',
      () async {
        var versionCalls = 0;
        var killCalls = <int>[];
        final adopted = PrintServerManager(
          serverVersion: ({timeout}) async {
            versionCalls++;
            return 4;
          },
          pidsOnPort: () async => <int>[9999],
          isPrintServer: (_) async => true,
          killProcess: (pid) async {
            killCalls.add(pid);
          },
        );

        await adopted.start();

        expect(adopted.isRunning, true);
        expect(versionCalls, greaterThan(0));
        expect(killCalls, isEmpty, reason: 'healthy server must not be killed');

        // stop() must not kill an adopted (shared) server.
        await adopted.stop();
        expect(adopted.isRunning, true);
      },
    );

    test(
      'kills a healthy-but-stale instance (version < 3) then launches fresh',
      () async {
        final killed = <int>[];
        final spawnedExes = <String>[];
        final freshProc = FakeProcess();
        final staleThenFresh = PrintServerManager(
          serverVersion: ({timeout}) async => 2,
          pidsOnPort: () async => <int>[7777],
          isPrintServer: (_) async => true,
          killProcess: (pid) async {
            killed.add(pid);
          },
          processFactory: (exe, args, {workingDirectory, runInShell}) async {
            spawnedExes.add(exe);
            return freshProc;
          },
          candidatePaths: [exePath],
        );

        await staleThenFresh.start();

        expect(killed, [7777], reason: 'stale v2 owner of port 5150 is killed');
        expect(spawnedExes, hasLength(1), reason: 'fresh binary is launched');
        expect(
          freshProc.wasKilled,
          true,
          reason: 'the launched copy also reports v2 → sacrificed',
        );
        expect(
          staleThenFresh.isRunning,
          false,
          reason: 'no usable PrintServer.exe remains',
        );
      },
    );

    test('unresponsive port kills stale then launches', () async {
      final killed = <int>[];
      final checked = <int>[];
      final spawnedExes = <String>[];
      final freshProc = FakeProcess();
      var started = false;
      final stale = PrintServerManager(
        serverVersion: ({timeout}) async => started ? 4 : null,
        pidsOnPort: () async => <int>[7777, 8888],
        isPrintServer: (pid) async {
          checked.add(pid);
          // Only PID 7777 belongs to PrintServer.exe.
          return pid == 7777;
        },
        killProcess: (pid) async {
          killed.add(pid);
        },
        processFactory: (exe, args, {workingDirectory, runInShell}) async {
          started = true;
          spawnedExes.add(exe);
          return freshProc;
        },
        candidatePaths: [exePath],
      );

      await stale.start();

      expect(checked, [7777, 8888]);
      expect(killed, [7777], reason: 'only PrintServer.exe must be killed');
      expect(
        spawnedExes,
        hasLength(1),
        reason: 'a fresh instance is launched on the freed port',
      );
      expect(stale.isRunning, true);
    });

    test('ignores non-PrintServer processes holding the port', () async {
      final killed = <int>[];
      final manager2 = PrintServerManager(
        serverVersion: ({timeout}) async => null,
        pidsOnPort: () async => <int>[4444],
        isPrintServer: (_) async => false,
        killProcess: (pid) async {
          killed.add(pid);
        },
        candidatePaths: const <String>[],
      );

      await manager2.start();

      expect(killed, isEmpty);
    });
  });

  group('PrintServerManager spawn retry', () {
    test('spawned binary reporting current version becomes running', () async {
      final spawnedExes = <String>[];
      final fakeProc = FakeProcess();
      var started = false;
      final m = PrintServerManager(
        serverVersion: ({timeout}) async => started ? 4 : null,
        pidsOnPort: () async => <int>[],
        processFactory: (exe, args, {workingDirectory, runInShell}) async {
          started = true;
          spawnedExes.add(exe);
          return fakeProc;
        },
        candidatePaths: [exePath],
      );

      await m.start();

      expect(spawnedExes, hasLength(1));
      expect(fakeProc.wasKilled, false);
      expect(m.isRunning, true);
    });

    test(
      'launched binary reporting stale version is killed and next candidate tried',
      () async {
        final firstProc = FakeProcess();
        final secondProc = FakeProcess();
        var spawned = 0;
        final spawnedExes = <String>[];
        final m = PrintServerManager(
          serverVersion: ({timeout}) async {
            if (spawned == 0) return null;
            if (spawned == 1) return firstProc.wasKilled ? null : 2;
            return 4;
          },
          pidsOnPort: () async => <int>[],
          processFactory: (exe, args, {workingDirectory, runInShell}) async {
            spawned++;
            spawnedExes.add(exe);
            return spawned == 1 ? firstProc : secondProc;
          },
          candidatePaths: [exePath, secondExePath],
        );

        await m.start();

        expect(
          spawnedExes,
          hasLength(2),
          reason: 'stale first candidate is sacrificed, second is tried',
        );
        expect(firstProc.wasKilled, true);
        expect(secondProc.wasKilled, false);
        expect(m.isRunning, true);

        // stop() must kill the instance we spawned ourselves.
        await m.stop();
        expect(secondProc.wasKilled, true);
      },
    );

    test('no usable exe → isRunning false', () async {
      var killCalls = 0;
      final m = PrintServerManager(
        serverVersion: ({timeout}) async => null,
        pidsOnPort: () async => <int>[],
        killProcess: (pid) async {
          killCalls++;
        },
        candidatePaths: const <String>[],
      );

      await m.start();

      expect(killCalls, 0);
      expect(m.isRunning, false);
    });
  });
}
