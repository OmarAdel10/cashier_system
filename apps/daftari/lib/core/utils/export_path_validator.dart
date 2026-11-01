import 'dart:io';

final RegExp _drivePathRegex = RegExp(r'^[a-zA-Z]:[\\/][^<>:"|?*\n]*$');

final RegExp _uncPathRegex = RegExp(
  r'^\\\\[^<>:"/|?*\n]+[\\/]?[^<>:"/|?*\n]*$',
);

/// POSIX absolute path: starts with `/`, segments cannot be empty (so `//` is
/// rejected) and NUL/newline characters are not allowed.
final RegExp _posixAbsolutePathRegex = RegExp(
  r'^/(?:[^/\u0000\n]+/)*[^/\u0000\n]*$',
);

/// Permissive structural check for absolute export directories.
///
/// On Linux (or when [linux] is true) accepts absolute POSIX paths such as
/// `/home/user/exports`. On other platforms accepts Windows drive-letter paths
/// (`C:\Exports`) and UNC paths (`\\server\share`). The app only converts `/`
/// to `\` on Windows (Linux picker results are stored as-is).
///
/// An empty path is considered valid so callers can treat "not set" as
/// acceptable input. [linux] can be passed explicitly (e.g. in tests) to
/// override platform detection.
bool isValidExportPath(String path, {bool? linux}) {
  if (path.isEmpty) return true;
  if (linux ?? Platform.isLinux) {
    return _posixAbsolutePathRegex.hasMatch(path);
  }
  return _drivePathRegex.hasMatch(path) || _uncPathRegex.hasMatch(path);
}
