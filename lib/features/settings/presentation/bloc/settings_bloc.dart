import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../data/models/app_settings_model.dart';
import '../../domain/repositories/i_settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends HydratedBloc<SettingsEvent, SettingsState> {
  final ISettingsRepository _repository;

  SettingsBloc({required ISettingsRepository repository})
      : _repository = repository,
        super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<LanguageToggled>(_onLanguageToggled);
    on<ThemeToggled>(_onThemeToggled);
    on<StoreNameChanged>(_onStoreNameChanged);
    on<ReceiptFootnoteChanged>(_onReceiptFootnoteChanged);
    on<CustomBindingsChanged>(_onCustomBindingsChanged);
  }

  Future<void> _onLoadSettings(
      LoadSettings event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final result = await _repository.getSettings();
    result.fold(
      (failure) => emit(state.copyWith(
          status: SettingsStatus.error, failure: failure)),
      (settings) => emit(state.copyWith(
          status: SettingsStatus.ready, settings: settings)),
    );
  }

  Future<void> _onLanguageToggled(
      LanguageToggled event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(languageCode: event.languageCode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onThemeToggled(
      ThemeToggled event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(isDarkMode: event.isDarkMode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStoreNameChanged(
      StoreNameChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(storeName: event.storeName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onReceiptFootnoteChanged(
      ReceiptFootnoteChanged event, Emitter<SettingsState> emit) async {
    final updated =
        state.settings.copyWith(receiptFootnote: event.receiptFootnote);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  void _onCustomBindingsChanged(
      CustomBindingsChanged event, Emitter<SettingsState> emit) {
    final resolved = _resolveBindingConflicts(
      currentBindings: state.settings.customBindings,
      actionToken: event.actionToken,
      keyCombo: event.keyCombo,
    );
    final updated =
        state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    _repository.saveSettings(updated);
  }

  Map<String, String> _resolveBindingConflicts({
    required Map<String, String> currentBindings,
    required String actionToken,
    required String keyCombo,
  }) {
    final resolved = Map<String, String>.from(currentBindings);
    final conflictKey = _findConflictKey(resolved, actionToken, keyCombo);
    if (conflictKey != null) {
      resolved.remove(conflictKey);
    }
    resolved[actionToken] = keyCombo;
    return resolved;
  }

  String? _findConflictKey(
      Map<String, String> bindings, String actionToken, String keyCombo) {
    for (final entry in bindings.entries) {
      if (entry.value == keyCombo && entry.key != actionToken) {
        return entry.key;
      }
    }
    return null;
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
        customBindings: state.settings.customBindings,
      ).toJson();
    } catch (_) {
      return null;
    }
  }
}
