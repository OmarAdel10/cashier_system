import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/app_settings_entity.dart';

abstract class ISettingsRepository {
  Future<Either<Failure, AppSettingsEntity>> getSettings();
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings);
}
