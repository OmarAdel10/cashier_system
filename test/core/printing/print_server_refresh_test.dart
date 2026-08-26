import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/printing/print_server_refresh.dart';

void main() {
  group('decidePublish', () {
    final newestSource = DateTime(2026, 8, 19, 10, 0, 0);

    test('csproj missing → none, even with stale exes on disk', () {
      final action = decidePublish(
        csprojExists: false,
        newestSourceModified: DateTime(2026, 8, 19, 9, 0, 0),
        candidateExes: [
          (path: r'C:\app\PrintServer.exe', modified: DateTime(2026, 8, 18)),
        ],
      );
      expect(action, PrintServerBuildAction.none);
    });

    test(
      'csproj present + first existing candidate newer than sources → none',
      () {
        final action = decidePublish(
          csprojExists: true,
          newestSourceModified: newestSource,
          candidateExes: [
            (
              path: r'C:\app\PrintServer.exe',
              modified: newestSource.add(const Duration(hours: 1)),
            ),
          ],
        );
        expect(action, PrintServerBuildAction.none);
      },
    );

    test(
      'csproj present + first candidate dated exactly equal to newest source → none',
      () {
        final action = decidePublish(
          csprojExists: true,
          newestSourceModified: newestSource,
          candidateExes: [
            (path: r'C:\app\PrintServer.exe', modified: newestSource),
          ],
        );
        expect(action, PrintServerBuildAction.none);
      },
    );

    test('csproj present + first candidate older than sources → publish', () {
      final action = decidePublish(
        csprojExists: true,
        newestSourceModified: newestSource,
        candidateExes: [
          (
            path: r'C:\app\PrintServer.exe',
            modified: newestSource.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(action, PrintServerBuildAction.publish);
    });

    test('csproj present + no exe candidates at all → publish', () {
      final action = decidePublish(
        csprojExists: true,
        newestSourceModified: newestSource,
        candidateExes: const [],
      );
      expect(action, PrintServerBuildAction.publish);
    });

    test(
      'csproj present + no source mtimes recorded → publish (cannot verify freshness)',
      () {
        final action = decidePublish(
          csprojExists: true,
          newestSourceModified: null,
          candidateExes: [
            (path: r'C:\app\PrintServer.exe', modified: DateTime(2030)),
          ],
        );
        expect(action, PrintServerBuildAction.publish);
      },
    );

    test(
      'csproj present + first candidate stale despite newer lower-priority exe → publish',
      () {
        final action = decidePublish(
          csprojExists: true,
          newestSourceModified: newestSource,
          candidateExes: [
            // The exe the manager will actually spawn (runner/Debug) is stale…
            (
              path: r'C:\build\windows\x64\runner\Debug\PrintServer.exe',
              modified: newestSource.subtract(const Duration(days: 2)),
            ),
            // …while a lower-priority fallback (bin/Debug) is fresh. A fresh
            // fallback must NOT mask the stale first candidate.
            (
              path: r'C:\PrintServer\bin\Debug\net8.0\PrintServer.exe',
              modified: newestSource.add(const Duration(days: 2)),
            ),
          ],
        );
        expect(action, PrintServerBuildAction.publish);
      },
    );

    test(
      'csproj present + first candidate fresh → none even with stale lower-priority exe',
      () {
        final action = decidePublish(
          csprojExists: true,
          newestSourceModified: newestSource,
          candidateExes: [
            (
              path: r'C:\build\windows\x64\runner\Debug\PrintServer.exe',
              modified: newestSource.add(const Duration(days: 2)),
            ),
            (
              path: r'C:\PrintServer\bin\Release\net8.0\PrintServer.exe',
              modified: newestSource.subtract(const Duration(days: 2)),
            ),
          ],
        );
        expect(action, PrintServerBuildAction.none);
      },
    );
  });
}
