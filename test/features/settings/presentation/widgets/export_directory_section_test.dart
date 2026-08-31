import 'package:cashier_system/core/utils/export_path_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportDirectoryPath validation', () {
    group('Windows paths (linux: false)', () {
      test('accepts standard Windows path', () {
        expect(isValidExportPath(r'D:\Exports', linux: false), isTrue);
      });

      test('accepts deep path with numbers and spaces', () {
        expect(
          isValidExportPath(r'C:\Users\Name\Folder 123', linux: false),
          isTrue,
        );
      });

      test('accepts multi-level path', () {
        expect(isValidExportPath(r'Z:\a\b\c\d\e', linux: false), isTrue);
      });

      test('accepts root-only path', () {
        expect(isValidExportPath(r'D:\', linux: false), isTrue);
      });

      test('accepts drive letter lowercase', () {
        expect(isValidExportPath(r'c:\windows\system32', linux: false), isTrue);
      });

      test('accepts UNC path', () {
        expect(
          isValidExportPath(r'\\server\share\folder', linux: false),
          isTrue,
        );
      });

      test('rejects relative path', () {
        expect(isValidExportPath('Exports', linux: false), isFalse);
      });

      test('rejects drive letter without backslash', () {
        expect(isValidExportPath('D:', linux: false), isFalse);
      });

      test('rejects path with pipe char', () {
        expect(isValidExportPath(r'C:\in|valid', linux: false), isFalse);
      });

      test('rejects path with question mark', () {
        expect(isValidExportPath(r'C:\inv?alid', linux: false), isFalse);
      });

      test('rejects path with asterisk', () {
        expect(isValidExportPath(r'C:\inv*alid', linux: false), isFalse);
      });

      test('accepts hyphen in folder name', () {
        expect(isValidExportPath(r'D:\my-folder\sub', linux: false), isTrue);
      });

      test('accepts underscore in folder name', () {
        expect(isValidExportPath(r'D:\my_folder\sub', linux: false), isTrue);
      });

      test('accepts dot in folder name', () {
        expect(isValidExportPath(r'D:\my.folder\sub', linux: false), isTrue);
      });
    });

    group('Linux paths (linux: true)', () {
      test('accepts root path', () {
        expect(isValidExportPath('/', linux: true), isTrue);
      });

      test('accepts standard absolute path', () {
        expect(isValidExportPath('/home/user/exports', linux: true), isTrue);
      });

      test('accepts XDG default export path', () {
        expect(
          isValidExportPath(
            '/home/user/.local/share/cashier-system/exports',
            linux: true,
          ),
          isTrue,
        );
      });

      test('accepts path with spaces, dots and hyphens', () {
        expect(
          isValidExportPath('/home/My Folder/exports.v1/sub-dir', linux: true),
          isTrue,
        );
      });

      test('accepts trailing slash', () {
        expect(isValidExportPath('/home/user/exports/', linux: true), isTrue);
      });

      test('rejects relative path', () {
        expect(isValidExportPath('home/user/exports', linux: true), isFalse);
      });

      test('rejects Windows drive path on Linux', () {
        expect(isValidExportPath(r'C:\Exports', linux: true), isFalse);
      });

      test('rejects double slashes', () {
        expect(isValidExportPath('/home//exports', linux: true), isFalse);
      });
    });

    test('accepts empty string as unset on any platform', () {
      expect(isValidExportPath(''), isTrue);
      expect(isValidExportPath('', linux: false), isTrue);
      expect(isValidExportPath('', linux: true), isTrue);
    });
  });
}
