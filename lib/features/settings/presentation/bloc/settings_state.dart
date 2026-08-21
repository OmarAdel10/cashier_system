import '../../../../core/error/failure.dart';
import '../../domain/entities/app_settings_entity.dart';

enum SettingsStatus { initial, loading, ready, error }

class SettingsState {
  final SettingsStatus status;
  final AppSettingsEntity settings;
  final Failure? failure;
  final List<String> shownPrepCategoryIds;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.settings = const AppSettingsEntity(),
    this.shownPrepCategoryIds = const [],
    this.failure,
  });

  SettingsState copyWith({
    SettingsStatus? status,
    AppSettingsEntity? settings,
    Failure? failure,
    List<String>? shownPrepCategoryIds,
  }) {
    return SettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      failure: failure ?? this.failure,
      shownPrepCategoryIds: shownPrepCategoryIds ?? this.shownPrepCategoryIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          settings == other.settings &&
          failure == other.failure &&
          shownPrepCategoryIds == other.shownPrepCategoryIds;

  @override
  int get hashCode =>
      status.hashCode ^
      settings.hashCode ^
      failure.hashCode ^
      shownPrepCategoryIds.hashCode;
}
