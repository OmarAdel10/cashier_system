import '../domain/entities/license_entity.dart';
import '../domain/enums/license_status.dart';
import '../infrastructure/crypto/ed25519_verifier.dart';
import '../infrastructure/hwid/hwid_provider.dart';
import '../infrastructure/hwid/windows_hwid_provider.dart';
import '../infrastructure/storage/file_backup_adapter.dart';
import '../infrastructure/storage/license_storage.dart';
import '../infrastructure/storage/secure_storage_adapter.dart';

class LicenseEngine {
  final HwidProvider _hwid;
  final LicenseStorage _primary;
  final LicenseStorage _backup;
  final Ed25519Verifier _verifier;

  String? _cachedDeviceId;

  LicenseEngine({
    HwidProvider? hwid,
    LicenseStorage? primary,
    LicenseStorage? backup,
    Ed25519Verifier? verifier,
  })  : _hwid = hwid ?? WindowsHwidProvider(),
        _primary = primary ?? SecureStorageAdapter(),
        _backup = backup ?? FileBackupAdapter(),
        _verifier = verifier ?? Ed25519Verifier();

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    _cachedDeviceId = await _hwid.getHardwareId();
    return _cachedDeviceId ?? 'UNKNOWN-MACHINE';
  }

  Future<LicenseStatus> verifyLicense() async {
    try {
      final deviceId = await getDeviceId();

      var detectedTampered = false;

      final primaryData = await _primary.read();
      if (primaryData != null) {
        final result = await _validateEntity(primaryData, deviceId);
        if (result == LicenseStatus.valid) return LicenseStatus.valid;
        detectedTampered = true;
      }

      final backupData = await _backup.read();
      if (backupData != null) {
        final result = await _validateEntity(backupData, deviceId);
        if (result == LicenseStatus.valid) {
          await _primary.write(backupData);
          return LicenseStatus.valid;
        }
        detectedTampered = true;
      }

      return detectedTampered ? LicenseStatus.tampered : LicenseStatus.invalid;
    } catch (_) {
      return LicenseStatus.invalid;
    }
  }

  Future<LicenseStatus> _validateEntity(LicenseEntity entity, String deviceId) async {
    if (entity.deviceId != deviceId) return LicenseStatus.tampered;
    final sigValid = await _verifier.verifySignature(
      deviceId: entity.deviceId,
      activationKey: entity.activationSignature,
    );
    return sigValid ? LicenseStatus.valid : LicenseStatus.tampered;
  }

  Future<bool> activate(String activationKey) async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == 'UNKNOWN-MACHINE') return false;

      final isValid = await _verifier.verifySignature(
        deviceId: deviceId,
        activationKey: activationKey,
      );
      if (!isValid) return false;

      final license = LicenseEntity(
        deviceId: deviceId,
        activationSignature: activationKey,
        activatedAt: DateTime.now(),
      );

      await _primary.write(license);
      await _backup.write(license);

      return true;
    } catch (_) {
      return false;
    }
  }

}
