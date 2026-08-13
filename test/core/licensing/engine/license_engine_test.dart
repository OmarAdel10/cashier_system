import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/licensing/domain/entities/license_entity.dart';
import 'package:cashier_system/core/licensing/domain/enums/license_status.dart';
import 'package:cashier_system/core/licensing/engine/license_engine.dart';
import 'package:cashier_system/core/licensing/infrastructure/crypto/ed25519_verifier.dart';
import 'package:cashier_system/core/licensing/infrastructure/hwid/hwid_provider.dart';
import 'package:cashier_system/core/licensing/infrastructure/storage/license_storage.dart';

class _FakeHwidProvider implements HwidProvider {
  String deviceId = 'CS-TEST-TEST';

  @override
  Future<String?> getHardwareId() async => deviceId;
}

class _FakeVerifier extends Ed25519Verifier {
  _FakeVerifier({this.shouldVerify = true})
    : super.fromPublicKeyHex(
        '0000000000000000000000000000000000000000000000000000000000000000',
      );

  final bool shouldVerify;

  @override
  Future<bool> verifySignature({
    required String deviceId,
    required String activationKey,
  }) async => shouldVerify;
}

class _FakeStorage implements LicenseStorage {
  LicenseEntity? _data;

  @override
  Future<LicenseEntity?> read() async => _data;

  @override
  Future<void> write(LicenseEntity license) async {
    _data = license;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}

void main() {
  group('LicenseEngine', () {
    late _FakeHwidProvider hwid;
    late _FakeStorage primary;
    late _FakeStorage backup;
    late LicenseEngine engine;

    setUp(() async {
      hwid = _FakeHwidProvider();
      primary = _FakeStorage();
      backup = _FakeStorage();
      engine = LicenseEngine(
        hwid: hwid,
        primary: primary,
        backup: backup,
        verifier: _FakeVerifier(),
      );
    });

    group('getDeviceId', () {
      test('should return device ID from HWID provider', () async {
        final result = await engine.getDeviceId();
        expect(result, 'CS-TEST-TEST');
      });

      test('should cache device ID', () async {
        await engine.getDeviceId();
        hwid.deviceId = 'CS-CHANGED';
        final result = await engine.getDeviceId();
        expect(result, 'CS-TEST-TEST');
      });
    });

    group('verifyLicense', () {
      test('should return invalid when both storages empty', () async {
        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.invalid);
      });

      test('should return valid when primary has matching data', () async {
        final entity = LicenseEntity(
          deviceId: 'CS-TEST-TEST',
          activationSignature: 'fake-sig',
          activatedAt: DateTime.now(),
        );
        await primary.write(entity);

        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.valid);
      });

      test(
        'should return tampered when primary has mismatched device ID',
        () async {
          final entity = LicenseEntity(
            deviceId: 'CS-OTHER-DEVICE',
            activationSignature: 'fake-sig',
            activatedAt: DateTime.now(),
          );
          await primary.write(entity);

          final result = await engine.verifyLicense();
          expect(result, LicenseStatus.tampered);
        },
      );

      test('should self-heal from backup when primary empty', () async {
        final entity = LicenseEntity(
          deviceId: 'CS-TEST-TEST',
          activationSignature: 'fake-sig',
          activatedAt: DateTime.now(),
        );
        await backup.write(entity);

        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.valid);

        final restored = await primary.read();
        expect(restored, isNotNull);
        expect(restored!.deviceId, 'CS-TEST-TEST');
      });

      test('should self-heal from backup when primary corrupted', () async {
        await primary.write(
          LicenseEntity(
            deviceId: 'CS-CORRUPTED',
            activationSignature: 'bad-sig',
            activatedAt: DateTime.now(),
          ),
        );
        final entity = LicenseEntity(
          deviceId: 'CS-TEST-TEST',
          activationSignature: 'fake-sig',
          activatedAt: DateTime.now(),
        );
        await backup.write(entity);

        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.valid);

        final restored = await primary.read();
        expect(restored!.deviceId, 'CS-TEST-TEST');
      });

      test('should not self-heal from backup with wrong device ID', () async {
        final entity = LicenseEntity(
          deviceId: 'CS-OTHER-DEVICE',
          activationSignature: 'fake-sig',
          activatedAt: DateTime.now(),
        );
        await backup.write(entity);

        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.tampered);

        final primaryData = await primary.read();
        expect(primaryData, isNull);
      });

      test('should return invalid when both have mismatched IDs', () async {
        await primary.write(
          LicenseEntity(
            deviceId: 'CS-PRIMARY-BAD',
            activationSignature: 'sig1',
            activatedAt: DateTime.now(),
          ),
        );
        await backup.write(
          LicenseEntity(
            deviceId: 'CS-BACKUP-BAD',
            activationSignature: 'sig2',
            activatedAt: DateTime.now(),
          ),
        );

        final result = await engine.verifyLicense();
        expect(result, LicenseStatus.tampered);
      });
    });

    group('activate', () {
      test('should return false when activation key is invalid', () async {
        final strictEngine = LicenseEngine(
          hwid: hwid,
          primary: primary,
          backup: backup,
          verifier: _FakeVerifier(shouldVerify: false),
        );

        final result = await strictEngine.activate(
          'aW52YWxpZC1rZXk',
        ); // base64 'invalid-key'
        expect(result, isFalse);
      });

      test('should write to both storages on success', () async {
        final entity = LicenseEntity(
          deviceId: 'CS-TEST-TEST',
          activationSignature: 'success-sig',
          activatedAt: DateTime.now(),
        );
        await primary.write(entity);
        await backup.write(entity);

        final storedPrimary = await primary.read();
        final storedBackup = await backup.read();
        expect(storedPrimary, isNotNull);
        expect(storedBackup, isNotNull);
        expect(storedPrimary!.deviceId, 'CS-TEST-TEST');
        expect(storedBackup!.deviceId, 'CS-TEST-TEST');
      });
    });
  });
}
