import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shortcuts/default_bindings.dart';
import '../../domain/repositories/i_settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
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
    on<SaveReceiptAsPdfToggled>(_onSaveReceiptAsPdfToggled);
    on<StoreAddressChanged>(_onStoreAddressChanged);
    on<StorePhoneNumberChanged>(_onStorePhoneNumberChanged);
    on<LogoSvgChanged>(_onLogoSvgChanged);
    on<ReceiptPrinterNameChanged>(_onReceiptPrinterNameChanged);
    on<BarcodePrinterNameChanged>(_onBarcodePrinterNameChanged);
    on<BarcodeActionPreferenceChanged>(_onBarcodeActionPreferenceChanged);
    on<PaymentTypeVisibilityChanged>(_onPaymentTypeVisibilityChanged);
    on<BusinessTypeChanged>(_onBusinessTypeChanged);
    on<MinimumGameCostChanged>(_onMinimumGameCostChanged);
    on<FavoritesStripChanged>(_onFavoritesStripChanged);
    on<RoomsToggled>(_onRoomsToggled);
    on<ServiceChargeToggled>(_onServiceChargeToggled);
    on<ServiceChargePercentChanged>(_onServiceChargePercentChanged);
    on<MinChargeToggled>(_onMinChargeToggled);
    on<MinChargePerTableChanged>(_onMinChargePerTableChanged);
    on<KitchenTicketsToggled>(_onKitchenTicketsToggled);
    on<KitchenPrinterNameChanged>(_onKitchenPrinterNameChanged);
    on<BarTicketsToggled>(_onBarTicketsToggled);
    on<BarPrinterNameChanged>(_onBarPrinterNameChanged);
    on<ShishaTicketsToggled>(_onShishaTicketsToggled);
    on<ShishaPrinterNameChanged>(_onShishaPrinterNameChanged);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final result = await _repository.getSettings();
    result.fold(
      (failure) =>
          emit(state.copyWith(status: SettingsStatus.error, failure: failure)),
      (settings) => emit(
        state.copyWith(status: SettingsStatus.ready, settings: settings),
      ),
    );
  }

  Future<void> _onLanguageToggled(
    LanguageToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(languageCode: event.languageCode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onThemeToggled(
    ThemeToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(isDarkMode: event.isDarkMode);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStoreNameChanged(
    StoreNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(storeName: event.storeName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onReceiptFootnoteChanged(
    ReceiptFootnoteChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      receiptFootnote: event.receiptFootnote,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onAddCustomBinding(
    AddCustomBinding event,
    Emitter<SettingsState> emit,
  ) async {
    // Work only with customBindings; defaults merged at gate level
    final customBindings = Map<String, List<String>>.from(
      state.settings.customBindings,
    );
    // Resolve conflicts within custom bindings only
    final resolved = _resolveAddConflict(
      currentBindings: customBindings,
      actionToken: event.actionToken,
      keyCombo: event.keyCombo,
    );
    // Check if this combo was a default for another action - add empty marker
    for (final entry in defaultBindings.entries) {
      if (entry.key != event.actionToken &&
          entry.value.contains(event.keyCombo)) {
        // This default combo is being stolen - mark as explicitly unbound,
        // but keep the victim's other custom combos (no wipe)
        resolved[entry.key] = (resolved[entry.key] ?? [])
            .where((c) => c != event.keyCombo)
            .toList();
      }
    }
    // Dedupe: don't add if already present
    final existing = resolved[event.actionToken] ?? [];
    resolved[event.actionToken] = existing.contains(event.keyCombo)
        ? existing
        : [...existing, event.keyCombo];
    final updated = state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onRemoveCustomBinding(
    RemoveCustomBinding event,
    Emitter<SettingsState> emit,
  ) async {
    final resolved = Map<String, List<String>>.from(
      state.settings.customBindings,
    );
    final list = resolved[event.actionToken];
    if (list == null) return;
    final updatedList = list.where((c) => c != event.keyCombo).toList();
    resolved[event.actionToken] = updatedList;
    // Drop empty-list markers whose defaults are no longer held by anyone
    _restoreDefaultsIfFree(resolved);
    final updated = state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onResetCustomBinding(
    ResetCustomBinding event,
    Emitter<SettingsState> emit,
  ) async {
    final resolved = Map<String, List<String>>.from(
      state.settings.customBindings,
    );
    resolved.remove(event.actionToken);
    _restoreDefaultsIfFree(resolved);
    final updated = state.settings.copyWith(customBindings: resolved);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onTaxToggled(
    TaxToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(taxEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onTaxPercentChanged(
    TaxPercentChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(taxPercent: event.percent);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onAutoPrintToggled(
    AutoPrintToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(autoPrintEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onUpdateOrderCounter(
    UpdateOrderCounter event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      orderCounter: event.counter,
      lastOrderDate: event.date,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onSetExportDirectoryPath(
    SetExportDirectoryPath event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(exportDirectoryPath: event.path);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    final result = await _repository.saveSettings(updated);
    result.fold(
      (failure) => emit(state.copyWith(
        status: SettingsStatus.error,
        failure: failure,
      )),
      (_) {},
    );
  }

  Future<void> _onSaveReceiptAsImageToggled(
    SaveReceiptAsImageToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(saveReceiptAsImage: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onSaveReceiptAsPdfToggled(
    SaveReceiptAsPdfToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(saveReceiptAsPdf: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStoreAddressChanged(
    StoreAddressChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(storeAddress: event.address);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onStorePhoneNumberChanged(
    StorePhoneNumberChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(storePhoneNumber: event.phone);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onLogoSvgChanged(
    LogoSvgChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(logoSvgData: event.data);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onReceiptPrinterNameChanged(
    ReceiptPrinterNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      receiptPrinterName: event.printerName,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBarcodePrinterNameChanged(
    BarcodePrinterNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      barcodePrinterName: event.printerName,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBarcodeActionPreferenceChanged(
    BarcodeActionPreferenceChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      barcodeActionPreference: event.value,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onPaymentTypeVisibilityChanged(
    PaymentTypeVisibilityChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(shownPaymentTypeIds: event.typeIds);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBusinessTypeChanged(
    BusinessTypeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(businessType: event.businessType);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onMinimumGameCostChanged(
    MinimumGameCostChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(minimumGameCost: event.cost);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onFavoritesStripChanged(
    FavoritesStripChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      favoritesStripEnabled: event.enabled,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onRoomsToggled(
    RoomsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(roomsEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onServiceChargeToggled(
    ServiceChargeToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      serviceChargeEnabled: event.enabled,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onServiceChargePercentChanged(
    ServiceChargePercentChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      serviceChargePercent: event.percent,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onMinChargeToggled(
    MinChargeToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(minChargeEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onMinChargePerTableChanged(
    MinChargePerTableChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      minChargePerTablePiastres: event.piastres,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onKitchenTicketsToggled(
    KitchenTicketsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      kitchenTicketsEnabled: event.enabled,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onKitchenPrinterNameChanged(
    KitchenPrinterNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      kitchenPrinterName: event.printerName,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBarTicketsToggled(
    BarTicketsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(barTicketsEnabled: event.enabled);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onBarPrinterNameChanged(
    BarPrinterNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(barPrinterName: event.printerName);
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onShishaTicketsToggled(
    ShishaTicketsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      shishaTicketsEnabled: event.enabled,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  Future<void> _onShishaPrinterNameChanged(
    ShishaPrinterNameChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final updated = state.settings.copyWith(
      shishaPrinterName: event.printerName,
    );
    emit(state.copyWith(settings: updated, status: SettingsStatus.ready));
    await _repository.saveSettings(updated);
  }

  /// Drops empty-list markers for every action whose defaults are no longer
  /// held by another action's custom bindings (thief removed/reset).
  ///
  /// The empty list is a steal-marker: it suppresses defaults that were
  /// bound elsewhere. Once no other action holds them, the defaults are
  /// safe to restore. Known accepted limitation: an explicit unbind of
  /// every custom combo on an action is indistinguishable from a marker, so
  /// its defaults also return.
  void _restoreDefaultsIfFree(Map<String, List<String>> resolved) {
    for (final key in resolved.keys.toList()) {
      final list = resolved[key];
      if (list == null || list.isNotEmpty) continue;
      var defaultHeldElsewhere = false;
      for (final defaultCombo in defaultBindings[key] ?? const <String>[]) {
        for (final entry in resolved.entries) {
          if (entry.key != key && entry.value.contains(defaultCombo)) {
            defaultHeldElsewhere = true;
            break;
          }
        }
        if (defaultHeldElsewhere) break;
      }
      if (!defaultHeldElsewhere) {
        resolved.remove(key);
      }
    }
  }

  Map<String, List<String>> _resolveAddConflict({
    required Map<String, List<String>> currentBindings,
    required String actionToken,
    required String keyCombo,
  }) {
    final resolved = currentBindings.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    );
    for (final entry in resolved.entries) {
      if (entry.key == actionToken) continue;
      entry.value.removeWhere((c) => c == keyCombo);
    }
    return resolved;
  }
}
