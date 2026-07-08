import '../entities/app_settings_entity.dart';

abstract class ISettingsRepository {
  Future<AppSettingsEntity> getSettings();
  Future<void> saveSettings(AppSettingsEntity settings);
}
