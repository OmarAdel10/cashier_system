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
