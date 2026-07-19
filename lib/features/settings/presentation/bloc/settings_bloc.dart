import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../../shortcuts/default_bindings.dart';
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
    on<AddCustomBinding>(_onAddCustomBinding);
    on<RemoveCustomBinding>(_onRemoveCustomBinding);
    on<ResetCustomBinding>(_onResetCustomBinding);
    on<TaxToggled>(_onTaxToggled);
    on<TaxPercentChanged>(_onTaxPercentChanged);
    on<AutoPrintToggled>(_onAutoPrintToggled);
    on<UpdateOrderCounter>(_onUpdateOrderCounter);
    on<SetExportDirectoryPath>(_onSetExportDirectoryPath);
    on<SaveReceiptAsImageToggled>(_onSaveReceiptAsImageToggled);
    on<StoreAddressChanged>(_onStoreAddressChanged);
    on<StorePhoneNumberChanged>(_onStorePhoneNumberChanged);
    on<LogoSvgPathChanged>(_onLogoSvgPathChanged);
    on<ReceiptPrinterNameChanged>(_onReceiptPrinterNameChanged);
    on<BarcodePrinterNameChanged>(_onBarcodePrinterNameChanged);
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

  Future<void> _onAddCustomBinding(
      AddCustomBinding event, Emitter<SettingsState> emit) async {
    final merged = {
      ...defaultBindings,
      ...state.settings.customBindings,
    };
    final resolved = _resolveAddConflict(
      currentBindings: merged,
      actionToken: event.actionToken,
      keyCombo: event.keyCombo,
    );
    resolved[event.actionToken] = [
      ...?resolved[event.actionToken],
      event.keyCombo,
    ];
    final customOnly = <String, List<String>>{};
    for (final entry in resolved.entries) {
      if (state.settings.customBindings.containsKey(entry.key) ||
          !defaultBindings.containsKey(entry.key)) {
        customOnly[entry.key] = entry.value;
      } else {
        final def = defaultBindings[entry.key]!;
        if (def.join(',') != entry.value.join(',')) {
          customOnly[entry.key] = entry.value;
        }
      }
    }
    customOnly.removeWhere((_, v) => v.isEmpty);
    final updated =
        state.settings.copyWith(customBindings: customOnly);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onRemoveCustomBinding(
      RemoveCustomBinding event, Emitter<SettingsState> emit) async {
    final resolved = Map<String, List<String>>.from(
        state.settings.customBindings);
    final list = resolved[event.actionToken];
    if (list == null) return;
    final updatedList = list
        .where((c) => c != event.keyCombo)
        .toList();
    if (updatedList.isEmpty) {
      resolved.remove(event.actionToken);
    } else {
      resolved[event.actionToken] = updatedList;
    }
    final updated =
        state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onResetCustomBinding(
      ResetCustomBinding event, Emitter<SettingsState> emit) async {
    final resolved = Map<String, List<String>>.from(
        state.settings.customBindings);
    resolved.remove(event.actionToken);
    final updated =
        state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onTaxToggled(
      TaxToggled event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(taxEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onTaxPercentChanged(
      TaxPercentChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(taxPercent: event.percent);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onAutoPrintToggled(
      AutoPrintToggled event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(autoPrintEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onUpdateOrderCounter(
      UpdateOrderCounter event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(
      orderCounter: event.counter,
      lastOrderDate: event.date,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onSetExportDirectoryPath(
      SetExportDirectoryPath event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(exportDirectoryPath: event.path);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onSaveReceiptAsImageToggled(
      SaveReceiptAsImageToggled event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(saveReceiptAsImage: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStoreAddressChanged(
      StoreAddressChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(storeAddress: event.address);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStorePhoneNumberChanged(
      StorePhoneNumberChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(storePhoneNumber: event.phone);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onLogoSvgPathChanged(
      LogoSvgPathChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(logoSvgPath: event.path);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onReceiptPrinterNameChanged(
      ReceiptPrinterNameChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(receiptPrinterName: event.printerName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBarcodePrinterNameChanged(
      BarcodePrinterNameChanged event, Emitter<SettingsState> emit) async {
    final updated = state.settings.copyWith(barcodePrinterName: event.printerName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Map<String, List<String>> _resolveAddConflict({
    required Map<String, List<String>> currentBindings,
    required String actionToken,
    required String keyCombo,
  }) {
    final resolved =
        currentBindings.map((k, v) => MapEntry(k, List<String>.from(v)));
    for (final entry in resolved.entries) {
      if (entry.key == actionToken) continue;
      entry.value.removeWhere((c) => c == keyCombo);
    }
    return resolved;
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
        taxEnabled: state.settings.taxEnabled,
        taxPercent: state.settings.taxPercent,
        autoPrintEnabled: state.settings.autoPrintEnabled,
        orderCounter: state.settings.orderCounter,
        lastOrderDate: state.settings.lastOrderDate,
        exportDirectoryPath: state.settings.exportDirectoryPath,
        saveReceiptAsImage: state.settings.saveReceiptAsImage,
        storeAddress: state.settings.storeAddress,
        storePhoneNumber: state.settings.storePhoneNumber,
        logoSvgPath: state.settings.logoSvgPath,
        receiptPrinterName: state.settings.receiptPrinterName,
        barcodePrinterName: state.settings.barcodePrinterName,
      ).toJson();
    } catch (_) {
      return null;
    }
  }
}
