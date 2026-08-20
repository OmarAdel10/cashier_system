/// Decision about whether the .NET sidecar must be republished before launch.
enum PrintServerBuildAction { none, publish }

/// Decides whether the .NET sidecar must be republished.
///
/// [csprojExists]: whether PrintServer/PrintServer.csproj exists in the
///   working tree (true in dev where the SDK repo is present; false in
///   installed/production layout).
/// [newestSourceModified]: newest last-modified time of any .cs/.csproj
///   source under the PrintServer project tree (ignoring bin/ and obj/),
///   or null when no sources exist.
/// [candidateExes]: the PrintServer.exe candidates from
///   PrintServerManager.exeCandidates(), as (path, lastModified) pairs for
///   existing files, in spawn-priority order.
///
/// Rules:
///  - If [csprojExists] == false → [PrintServerBuildAction.none]. Installed
///    layouts ship their own server build and never have the SDK, so we must
///    never attempt a build.
///  - Else if no candidate exe exists → [PrintServerBuildAction.publish]. The
///    manager has nothing to spawn.
///  - Else if the FIRST existing candidate (the exe the manager will actually
///    spawn) is missing or older than [newestSourceModified] →
///    [PrintServerBuildAction.publish]. Only this candidate matters: it is
///    what runs, so a fresher exe in a lower-priority path must not mask a
///    stale one (republish overwrites runner/Debug, which outranks every
///    fallback path on the next start).
///  - Else → [PrintServerBuildAction.none].
PrintServerBuildAction decidePublish({
  required bool csprojExists,
  required DateTime? newestSourceModified,
  required List<({String path, DateTime modified})> candidateExes,
}) {
  if (!csprojExists) return PrintServerBuildAction.none;

  final newestSource = newestSourceModified;
  if (newestSource == null) {
    // No sources recorded, cannot verify the exe is fresh — safest to build.
    return PrintServerBuildAction.publish;
  }

  final first = candidateExes.isEmpty ? null : candidateExes.first;
  if (first == null || first.modified.isBefore(newestSource)) {
    return PrintServerBuildAction.publish;
  }

  return PrintServerBuildAction.none;
}