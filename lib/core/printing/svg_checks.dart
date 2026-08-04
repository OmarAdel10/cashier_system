import 'dart:convert';

/// Result of the local quick sanity check performed before the authoritative
/// PrintServer validation call.
class SvgQuickCheckResult {
  const SvgQuickCheckResult.valid()
      : valid = true,
        errorCode = null;

  const SvgQuickCheckResult.invalid(this.errorCode) : valid = false;

  final bool valid;
  final String? errorCode;
}

/// Cheap client-side SVG pre-screening.
///
/// Mirrors the error codes returned by PrintServer's `/api/printing/validate-svg`
/// endpoint (`NOT_SVG`, `TOO_LARGE`) plus a local `UNSAFE_CONTENT` code, so the
/// upload flow can map every failure to one localized message.
abstract final class SvgQuickCheck {
  static const int maxBytes = 5 * 1024 * 1024;

  static const String _codeNotSvg = 'NOT_SVG';
  static const String _codeTooLarge = 'TOO_LARGE';
  static const String _codeUnsafeContent = 'UNSAFE_CONTENT';

  static const List<String> _dangerTokens = [
    '<script',
    '<!doctype',
    '<!entity',
    ' onload=',
    ' onerror=',
    ' onclick=',
    'javascript:',
    '@import',
    'url(http',
    'url(https',
  ];

  static final RegExp _doctypeName = RegExp(
    r'<!DOCTYPE\s+([A-Za-z_][\w.:-]*)',
    caseSensitive: false,
  );

  static final RegExp _refAttr = RegExp(
    r'''(?:href|xlink:href|src)\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  static SvgQuickCheckResult check(List<int> bytes) {
    if (bytes.length > maxBytes) {
      return const SvgQuickCheckResult.invalid(_codeTooLarge);
    }

    final text = _decodeUtf8(bytes);
    if (text == null || !_looksLikeSvg(text)) {
      return const SvgQuickCheckResult.invalid(_codeNotSvg);
    }

    final doctype = _doctypeName.firstMatch(text);
    if (doctype != null &&
        doctype.group(1)!.toLowerCase() != 'svg') {
      return const SvgQuickCheckResult.invalid(_codeNotSvg);
    }

    final lowered = text.toLowerCase();
    for (final token in _dangerTokens) {
      if (lowered.contains(token)) {
        return const SvgQuickCheckResult.invalid(_codeUnsafeContent);
      }
    }

    for (final match in _refAttr.allMatches(text)) {
      if (_isUnsafeReference(match.group(1)!)) {
        return const SvgQuickCheckResult.invalid(_codeUnsafeContent);
      }
    }

    return const SvgQuickCheckResult.valid();
  }

  /// Mirrors the server's `IsSafeReference`: only `#fragment`, `data:image/`
  /// URIs and scheme-less relative references are allowed.
  static bool _isUnsafeReference(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('#')) return false;

    final lower = v.toLowerCase();
    if (lower.startsWith('data:image/')) return false;
    if (lower.startsWith('http:') ||
        lower.startsWith('https:') ||
        lower.startsWith('file:') ||
        lower.startsWith('javascript:') ||
        lower.contains('://') ||
        lower.contains('%3a')) {
      return true;
    }

    return v.indexOf(':') > 0;
  }

  static String? _decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return null;
    }
  }

  static bool _looksLikeSvg(String text) {
    var trimmed = text.replaceFirst('\uFEFF', '');
    trimmed = trimmed.trimLeft();
    return trimmed.startsWith('<svg') ||
        trimmed.startsWith('<?xml') ||
        trimmed.startsWith('<!--') ||
        trimmed.startsWith('<!DOCTYPE');
  }
}
