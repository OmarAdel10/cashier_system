import 'package:cashier_system/core/utils/export_path_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportDirectoryPath validation', () {
    test('accepts standard Windows path', () {
      expect(isValidExportPath(r'D:\Exports'), isTrue);
    });

    test('accepts deep path with numbers and spaces', () {
      expect(isValidExportPath(r'C:\Users\Name\Folder 123'), isTrue);
    });

    test('accepts multi-level path', () {
      expect(isValidExportPath(r'Z:\a\b\c\d\e'), isTrue);
    });

    test('accepts root-only path', () {
      expect(isValidExportPath(r'D:\'), isTrue);
    });

    test('accepts drive letter lowercase', () {
      expect(isValidExportPath(r'c:\windows\system32'), isTrue);
    });

    test('accepts UNC path', () {
      expect(isValidExportPath(r'\\server\share\folder'), isTrue);
    });

    test('accepts empty string as unset', () {
      expect(isValidExportPath(''), isTrue);
    });

    test('rejects Unix path', () {
      expect(isValidExportPath('/usr/local'), isFalse);
    });

    test('rejects drive letter without backslash', () {
      expect(isValidExportPath('D:'), isFalse);
    });

    test('rejects path with pipe char', () {
      expect(isValidExportPath(r'C:\in|valid'), isFalse);
    });

    test('rejects path with question mark', () {
      expect(isValidExportPath(r'C:\inv?alid'), isFalse);
    });

    test('rejects path with asterisk', () {
      expect(isValidExportPath(r'C:\inv*alid'), isFalse);
    });

    test('accepts hyphen in folder name', () {
      expect(isValidExportPath(r'D:\my-folder\sub'), isTrue);
    });

    test('accepts underscore in folder name', () {
      expect(isValidExportPath(r'D:\my_folder\sub'), isTrue);
    });

    test('accepts dot in folder name', () {
      expect(isValidExportPath(r'D:\my.folder\sub'), isTrue);
    });
  });
}