sealed class SettingsEvent {
  const SettingsEvent();
}

final class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

final class LanguageToggled extends SettingsEvent {
  final String languageCode;
  const LanguageToggled(this.languageCode);
}

final class ThemeToggled extends SettingsEvent {
  final bool isDarkMode;
  const ThemeToggled(this.isDarkMode);
}

final class StoreNameChanged extends SettingsEvent {
  final String storeName;
  const StoreNameChanged(this.storeName);
}

final class ReceiptFootnoteChanged extends SettingsEvent {
  final String receiptFootnote;
  const ReceiptFootnoteChanged(this.receiptFootnote);
}

final class AddCustomBinding extends SettingsEvent {
  final String actionToken;
  final String keyCombo;
  const AddCustomBinding(this.actionToken, this.keyCombo);
}

final class RemoveCustomBinding extends SettingsEvent {
  final String actionToken;
  final String keyCombo;
  const RemoveCustomBinding(this.actionToken, this.keyCombo);
}

final class ResetCustomBinding extends SettingsEvent {
  final String actionToken;
  const ResetCustomBinding(this.actionToken);
}

final class TaxToggled extends SettingsEvent {
  final bool enabled;
  const TaxToggled(this.enabled);
}

final class TaxPercentChanged extends SettingsEvent {
  final int percent;
  const TaxPercentChanged(this.percent);
}

final class AutoPrintToggled extends SettingsEvent {
  final bool enabled;
  const AutoPrintToggled(this.enabled);
}

final class UpdateOrderCounter extends SettingsEvent {
  final int counter;
  final String date;
  const UpdateOrderCounter(this.counter, this.date);
}

final class SetBarcodeDownloadPath extends SettingsEvent {
  final String path;
  const SetBarcodeDownloadPath(this.path);
}
