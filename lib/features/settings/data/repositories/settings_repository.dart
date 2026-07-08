import 'package:hive/hive.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../models/app_settings_model.dart';

class SettingsRepository implements ISettingsRepository {
  final Box<AppSettingsModel> _box;

  SettingsRepository({required Box<AppSettingsModel> box}) : _box = box;

  @override
  Future<AppSettingsEntity> getSettings() async {
    final model = _box.get('settings');
    if (model == null) return const AppSettingsEntity();
    return model.toEntity();
  }

  @override
  Future<void> saveSettings(AppSettingsEntity settings) async {
    final model = AppSettingsModel(
      languageCode: settings.languageCode,
      isDarkMode: settings.isDarkMode,
      storeName: settings.storeName,
      receiptFootnote: settings.receiptFootnote,
    );
    await _box.put('settings', model);
  }
}
