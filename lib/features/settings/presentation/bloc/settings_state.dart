import '../../domain/entities/app_settings_entity.dart';

enum SettingsStatus { initial, loading, ready, error }

class SettingsState {
  final SettingsStatus status;
  final AppSettingsEntity settings;
  final String? errorMessage;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = const AppSettingsEntity(),
    this.errorMessage,
  });

  SettingsState copyWith({
    SettingsStatus? status,
    AppSettingsEntity? settings,
    String? errorMessage,
  }) {
    return SettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          settings == other.settings &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => status.hashCode ^ settings.hashCode ^ errorMessage.hashCode;
}
