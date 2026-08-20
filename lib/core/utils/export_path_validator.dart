final RegExp _drivePathRegex = RegExp(
  r'^[a-zA-Z]:[\\/][^<>:"|?*\n]*$',
);

final RegExp _uncPathRegex = RegExp(
  r'^\\\\[^<>:"/|?*\n]+[\\/]?[^<>:"/|?*\n]*$',
);

/// Permissive structural check for Windows export directories.
///
/// Accepts drive-letter paths (`C:\Exports`) and UNC paths
/// (`\\server\share`), normalizing forward slashes (the app converts `/` to
/// `\` before persisting). An empty path is considered valid so callers can
/// treat "not set" as acceptable input.
bool isValidExportPath(String path) {
  if (path.isEmpty) return true;
  return _drivePathRegex.hasMatch(path) || _uncPathRegex.hasMatch(path);
}