import 'package:cashier_system/core/licensing/domain/enums/license_status.dart';
import 'package:cashier_system/core/licensing/engine/license_engine.dart';

class FakeLicenseEngine extends LicenseEngine {
  final bool _quickVerifyResult;
  final LicenseStatus _verifyResult;
  final bool _activateResult;
  final String _deviceId;

  FakeLicenseEngine({
    bool quickVerifyResult = true,
    LicenseStatus verifyResult = LicenseStatus.valid,
    bool activateResult = true,
    String deviceId = 'CS-TEST-TEST',
  })  : _quickVerifyResult = quickVerifyResult,
        _verifyResult = verifyResult,
        _activateResult = activateResult,
        _deviceId = deviceId;

  @override
  Future<bool> quickVerify() async => _quickVerifyResult;

  @override
  Future<LicenseStatus> verifyLicense() async => _verifyResult;

  @override
  Future<bool> activate(String activationKey) async => _activateResult;

  @override
  Future<String> getDeviceId() async => _deviceId;
}
