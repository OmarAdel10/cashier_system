import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/license_entity.dart';
import 'license_storage.dart';

class FileBackupAdapter implements LicenseStorage {
  static final List<int> _xorMask = [
    0xAB,
    0xCD,
    0xEF,
    0x12,
    0x34,
    0x56,
    0x78,
    0x90,
  ];
  static const _fileName = 'license.lic';
  static const _subDir = 'CashierSystem';

  @override
  Future<LicenseEntity?> read() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final obfuscated = await file.readAsString();
      final json = _deobfuscate(obfuscated);
      return LicenseEntity.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(LicenseEntity license) async {
    final file = await _getFile();
    await file.parent.create(recursive: true);
    final json = jsonEncode(license.toJson());
    await file.writeAsString(_obfuscate(json));
  }

  @override
  Future<void> clear() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _obfuscate(String data) {
    final bytes = utf8.encode(data);
    final masked = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      masked.add(bytes[i] ^ _xorMask[i % _xorMask.length]);
    }
    return base64Url.encode(masked);
  }

  String _deobfuscate(String data) {
    final masked = base64Url.decode(data);
    final bytes = <int>[];
    for (var i = 0; i < masked.length; i++) {
      bytes.add(masked[i] ^ _xorMask[i % _xorMask.length]);
    }
    return utf8.decode(bytes);
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_subDir/$_fileName');
  }
}
