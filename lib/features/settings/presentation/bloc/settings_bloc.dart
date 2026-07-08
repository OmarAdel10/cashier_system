import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../data/models/app_settings_model.dart';
import '../../domain/entities/app_settings_entity.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends HydratedBloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<LanguageToggled>(_onLanguageToggled);
    on<ThemeToggled>(_onThemeToggled);
    on<StoreNameChanged>(_onStoreNameChanged);
    on<ReceiptFootnoteChanged>(_onReceiptFootnoteChanged);
  }

  void _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) {
    emit(state.copyWith(status: SettingsStatus.ready));
  }

  void _onLanguageToggled(LanguageToggled event, Emitter<SettingsState> emit) {
    final updated = state.settings.copyWith(languageCode: event.languageCode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
  }

  void _onThemeToggled(ThemeToggled event, Emitter<SettingsState> emit) {
    final updated = state.settings.copyWith(isDarkMode: event.isDarkMode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
  }

  void _onStoreNameChanged(StoreNameChanged event, Emitter<SettingsState> emit) {
    final updated = state.settings.copyWith(storeName: event.storeName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
  }

  void _onReceiptFootnoteChanged(ReceiptFootnoteChanged event, Emitter<SettingsState> emit) {
    final updated = state.settings.copyWith(receiptFootnote: event.receiptFootnote);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    try {
      final model = AppSettingsModel.fromJson(json);
      return SettingsState(
        status: SettingsStatus.ready,
        settings: model.toEntity(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    try {
      return AppSettingsModel(
        languageCode: state.settings.languageCode,
        isDarkMode: state.settings.isDarkMode,
        storeName: state.settings.storeName,
        receiptFootnote: state.settings.receiptFootnote,
      ).toJson();
    } catch (_) {
      return null;
    }
  }
}
