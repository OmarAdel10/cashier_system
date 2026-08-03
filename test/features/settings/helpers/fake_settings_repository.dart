import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/domain/repositories/i_settings_repository.dart';

class FakeSettingsRepository implements ISettingsRepository {
  AppSettingsEntity _settings;

  FakeSettingsRepository([AppSettingsEntity initial = const AppSettingsEntity()])
      : _settings = initial;

  @override
  Future<Either<Failure, AppSettingsEntity>> getSettings() async {
    return Right(_settings);
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings) async {
    _settings = settings;
    return const Right(null);
  }
}
