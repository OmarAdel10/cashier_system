import 'dart:convert';

import 'package:cashier_system/core/printing/svg_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SvgQuickCheck', () {
    test('accepts a well-formed icon SVG', () {
      final svg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
          '<rect width="32" height="32" fill="#ff0000"/></svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isTrue);
    });

    test('accepts SVG with XML prolog and comment', () {
      final svg =
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<!-- comment -->\n'
          '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
          '<circle cx="5" cy="5" r="5"/></svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isTrue);
    });

    test('rejects oversized files with TOO_LARGE', () {
      final bytes = List<int>.filled(SvgQuickCheck.maxBytes + 1, 32);

      final result = SvgQuickCheck.check(bytes);

      expect(result.valid, isFalse);
      expect(result.errorCode, 'TOO_LARGE');
    });

    test('rejects non-SVG bytes with NOT_SVG', () {
      final result = SvgQuickCheck.check([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);

      expect(result.valid, isFalse);
      expect(result.errorCode, 'NOT_SVG');
    });

    test('rejects HTML disguised as SVG with NOT_SVG', () {
      final result = SvgQuickCheck.check(utf8.encode('<!DOCTYPE html>'
          '<html><body>scam</body></html>'));

      expect(result.valid, isFalse);
      expect(result.errorCode, 'NOT_SVG');
    });

    test('rejects invalid UTF-8 bytes with NOT_SVG', () {
      final result = SvgQuickCheck.check([0x3C, 0x73, 0xFF, 0xFE, 0x00]);

      expect(result.valid, isFalse);
      expect(result.errorCode, 'NOT_SVG');
    });

    test('rejects script tag with UNSAFE_CONTENT', () {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg">'
          '<script>alert(1)</script></svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isFalse);
      expect(result.errorCode, 'UNSAFE_CONTENT');
    });

    test('rejects DOCTYPE with entity declaration as UNSAFE_CONTENT', () {
      final svg = '<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
          '<svg xmlns="http://www.w3.org/2000/svg"/>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isFalse);
      expect(result.errorCode, 'UNSAFE_CONTENT');
    });

    test('rejects onload event attribute as UNSAFE_CONTENT', () {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)">'
          '<rect width="10" height="10"/></svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isFalse);
      expect(result.errorCode, 'UNSAFE_CONTENT');
    });

    test('rejects external http reference as UNSAFE_CONTENT', () {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg">'
          '<image href="http://evil.example/x.png" width="10" height="10"/>'
          '</svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isFalse);
      expect(result.errorCode, 'UNSAFE_CONTENT');
    });

    test('allows fragment gradient reference (no false positive)', () {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg">'
          '<defs><linearGradient id="g"><stop offset="0" stop-color="#f00"/>'
          '</linearGradient></defs>'
          '<rect width="10" height="10" fill="url(#g)"/></svg>';

      final result = SvgQuickCheck.check(utf8.encode(svg));

      expect(result.valid, isTrue);
    });
  });
}
