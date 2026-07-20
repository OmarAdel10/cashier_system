import '../../domain/entities/license_entity.dart';

abstract class LicenseStorage {
  Future<LicenseEntity?> read();
  Future<void> write(LicenseEntity license);
  Future<void> clear();
}
