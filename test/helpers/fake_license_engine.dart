import 'package:cashier_system/core/licensing/domain/enums/license_status.dart';
import 'package:cashier_system/core/licensing/engine/license_engine.dart';
import 'package:cashier_system/core/licensing/infrastructure/crypto/ed25519_verifier.dart';

class FakeLicenseEngine extends LicenseEngine {
  final LicenseStatus _verifyResult;
  final bool _activateResult;
  final String _deviceId;

  FakeLicenseEngine({
    LicenseStatus verifyResult = LicenseStatus.valid,
    bool activateResult = true,
    String deviceId = 'CS-TEST-TEST',
  }) : _verifyResult = verifyResult,
       _activateResult = activateResult,
       _deviceId = deviceId,
       super(
         verifier: Ed25519Verifier.fromPublicKeyHex(
           '0000000000000000000000000000000000000000000000000000000000000000',
         ),
       );

  @override
  Future<LicenseStatus> verifyLicense() async => _verifyResult;

  @override
  Future<bool> activate(String activationKey) async => _activateResult;

  @override
  Future<String> getDeviceId() async => _deviceId;
}
