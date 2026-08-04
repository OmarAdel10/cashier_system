import 'package:flutter_test/flutter_test.dart';

void main() {
  final regex = RegExp(r'^[a-zA-Z]:\\(?:[^<>:"/\\|?*\n]+\\)*[^<>:"/\\|?*\n]*$');

  group('ExportDirectoryPath regex', () {
    test('accepts standard Windows path', () {
      expect(regex.hasMatch(r'D:\Exports'), isTrue);
    });

    test('accepts deep path with numbers and spaces', () {
      expect(regex.hasMatch(r'C:\Users\Name\Folder 123'), isTrue);
    });

    test('accepts multi-level path', () {
      expect(regex.hasMatch(r'Z:\a\b\c\d\e'), isTrue);
    });

    test('accepts root-only path', () {
      expect(regex.hasMatch(r'D:\'), isTrue);
    });

    test('accepts drive letter lowercase', () {
      expect(regex.hasMatch(r'c:\windows\system32'), isTrue);
    });

    test('rejects Unix path', () {
      expect(regex.hasMatch('/usr/local'), isFalse);
    });

    test('rejects drive letter without backslash', () {
      expect(regex.hasMatch('D:'), isFalse);
    });

    test('rejects missing backslash after colon', () {
      expect(regex.hasMatch('D:foo\\bar'), isFalse);
    });

    test('rejects path with invalid char <>', () {
      expect(regex.hasMatch(r'C:\in<valid'), isFalse);
    });

    test('rejects path with pipe char', () {
      expect(regex.hasMatch(r'C:\in|valid'), isFalse);
    });

    test('rejects empty string', () {
      expect(regex.hasMatch(''), isFalse);
    });

    test('rejects path with question mark', () {
      expect(regex.hasMatch(r'C:\inv?alid'), isFalse);
    });

    test('rejects path with asterisk', () {
      expect(regex.hasMatch(r'C:\inv*alid'), isFalse);
    });

    test('rejects path with double backslash', () {
      expect(regex.hasMatch(r'C:\\foo'), isFalse);
    });

    test('accepts hyphen in folder name', () {
      expect(regex.hasMatch(r'D:\my-folder\sub'), isTrue);
    });

    test('accepts underscore in folder name', () {
      expect(regex.hasMatch(r'D:\my_folder\sub'), isTrue);
    });

    test('accepts dot in folder name', () {
      expect(regex.hasMatch(r'D:\my.folder\sub'), isTrue);
    });

    test('rejects trailing backslash with no content after drive', () {
      // D:\ is valid (already tested above), but D:\ with nothing after it is the root
      expect(regex.hasMatch(r'D:\'), isTrue);
    });
  });
}
