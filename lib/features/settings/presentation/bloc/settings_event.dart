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

final class SetExportDirectoryPath extends SettingsEvent {
  final String path;
  const SetExportDirectoryPath(this.path);
}

final class SaveReceiptAsImageToggled extends SettingsEvent {
  final bool enabled;
  const SaveReceiptAsImageToggled(this.enabled);
}

final class SaveReceiptAsPdfToggled extends SettingsEvent {
  final bool enabled;
  const SaveReceiptAsPdfToggled(this.enabled);
}

final class StoreAddressChanged extends SettingsEvent {
  final String address;
  const StoreAddressChanged(this.address);
}

final class StorePhoneNumberChanged extends SettingsEvent {
  final String phone;
  const StorePhoneNumberChanged(this.phone);
}

final class LogoSvgChanged extends SettingsEvent {
  final String? data;
  const LogoSvgChanged(this.data);
}

final class ReceiptPrinterNameChanged extends SettingsEvent {
  final String? printerName;
  const ReceiptPrinterNameChanged(this.printerName);
}

final class BarcodePrinterNameChanged extends SettingsEvent {
  final String? printerName;
  const BarcodePrinterNameChanged(this.printerName);
}

final class RefreshLocalPrinters extends SettingsEvent {
  const RefreshLocalPrinters();
}

final class BarcodeActionPreferenceChanged extends SettingsEvent {
  final String value;
  const BarcodeActionPreferenceChanged(this.value);
}

final class PaymentTypeVisibilityChanged extends SettingsEvent {
  final List<String> typeIds;
  const PaymentTypeVisibilityChanged(this.typeIds);
}

final class PrepCategoryVisibilityChanged extends SettingsEvent {
  final List<String> typeIds;
  const PrepCategoryVisibilityChanged(this.typeIds);}

final class BusinessTypeChanged extends SettingsEvent {
  final String businessType;
  const BusinessTypeChanged(this.businessType);
}

final class MinimumGameCostChanged extends SettingsEvent {
  final int cost;
  const MinimumGameCostChanged(this.cost);
}

final class FavoritesStripChanged extends SettingsEvent {
  final bool enabled;
  const FavoritesStripChanged(this.enabled);
}

final class RoomsToggled extends SettingsEvent {
  final bool enabled;
  const RoomsToggled(this.enabled);
}

final class ServiceChargeToggled extends SettingsEvent {
  final bool enabled;
  const ServiceChargeToggled(this.enabled);
}

final class ServiceChargePercentChanged extends SettingsEvent {
  final int percent;
  const ServiceChargePercentChanged(this.percent);
}

final class MinChargeToggled extends SettingsEvent {
  final bool enabled;
  const MinChargeToggled(this.enabled);
}

final class MinChargePerTableChanged extends SettingsEvent {
  final int piastres;
  const MinChargePerTableChanged(this.piastres);
}

final class KitchenTicketsToggled extends SettingsEvent {
  final bool enabled;
  const KitchenTicketsToggled(this.enabled);
}

final class KitchenPrinterNameChanged extends SettingsEvent {
  final String? printerName;
  const KitchenPrinterNameChanged(this.printerName);
}

final class BarTicketsToggled extends SettingsEvent {
  final bool enabled;
  const BarTicketsToggled(this.enabled);
}

final class BarPrinterNameChanged extends SettingsEvent {
  final String? printerName;
  const BarPrinterNameChanged(this.printerName);
}

final class ShishaTicketsToggled extends SettingsEvent {
  final bool enabled;
  const ShishaTicketsToggled(this.enabled);
}

final class ShishaPrinterNameChanged extends SettingsEvent {
  final String? printerName;
  const ShishaPrinterNameChanged(this.printerName);
}
