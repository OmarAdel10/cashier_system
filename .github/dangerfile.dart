import 'package:danger_core/danger_core.dart';

void main() {
  // Warn if PR title indicates Work In Progress
  final prTitle = danger.github.pr.title.toLowerCase();
  if (prTitle.contains('wip')) {
    warn('This PR is marked as Work In Progress (WIP).');
  }

  // Encourage small PRs
  final additions = danger.github.pr.additions ?? 0;
  final deletions = danger.github.pr.deletions ?? 0;
  if (additions + deletions > 500) {
    warn(
      'Big PR! Consider splitting this into smaller pull requests for easier review.',
    );
  }

  // Remind to update pubspec.lock if pubspec.yaml changed
  final modifiedFiles = danger.git.modifiedFiles;
  if (modifiedFiles.contains('pubspec.yaml') &&
      !modifiedFiles.contains('pubspec.lock')) {
    fail('You updated `pubspec.yaml` without committing `pubspec.lock`.');
  }
}
