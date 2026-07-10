import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../models/app_settings_model.dart';

class SettingsRepository implements ISettingsRepository {
  final Box<AppSettingsModel> _box;

  SettingsRepository({required Box<AppSettingsModel> box}) : _box = box;

  @override
  Future<Either<Failure, AppSettingsEntity>> getSettings() async {
    try {
      final model = _box.get('settings');
      if (model == null) return Right(const AppSettingsEntity());
      return Right(model.toEntity());
    } catch (e) {
      return Left(DatabaseFailure('Failed to load settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings) async {
    try {
      final model = AppSettingsModel(
        languageCode: settings.languageCode,
        isDarkMode: settings.isDarkMode,
        storeName: settings.storeName,
        receiptFootnote: settings.receiptFootnote,
        customBindings: settings.customBindings,
      );
      await _box.put('settings', model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save settings: $e'));
    }
  }
}
