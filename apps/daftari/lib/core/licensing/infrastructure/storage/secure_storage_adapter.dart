import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/license_entity.dart';
import 'license_storage.dart';

class SecureStorageAdapter implements LicenseStorage {
  static const _key = 'license_data';

  final FlutterSecureStorage _storage;

  SecureStorageAdapter({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<LicenseEntity?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LicenseEntity.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(LicenseEntity license) async {
    await _storage.write(key: _key, value: jsonEncode(license.toJson()));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
