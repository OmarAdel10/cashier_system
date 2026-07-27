class AppSettingsEntity {
  final String languageCode;
  final bool isDarkMode;
  final String storeName;
  final String receiptFootnote;
  final Map<String, List<String>> customBindings;
  final bool taxEnabled;
  final int taxPercent;
  final bool autoPrintEnabled;
  final int orderCounter;
  final String lastOrderDate;
  final String exportDirectoryPath;
  final bool saveReceiptAsImage;
  final String storeAddress;
  final String storePhoneNumber;
  final String? logoSvgPath;
  final String? logoSvgData;
  final String? receiptPrinterName;
  final String? barcodePrinterName;
  final String barcodeActionPreference;

  const AppSettingsEntity({
    this.languageCode = 'ar',
    this.isDarkMode = false,
    this.storeName = '',
    this.receiptFootnote = 'Thanks',
    this.customBindings = const {},
    this.taxEnabled = false,
    this.taxPercent = 0,
    this.autoPrintEnabled = false,
    this.orderCounter = 0,
    this.lastOrderDate = '',
    this.exportDirectoryPath = '',
    this.saveReceiptAsImage = false,
    this.storeAddress = '',
    this.storePhoneNumber = '',
    this.logoSvgPath,
    this.logoSvgData,
    this.receiptPrinterName,
    this.barcodePrinterName,
    this.barcodeActionPreference = 'printDirect',
  });

  bool get isRtl => languageCode == 'ar';

  AppSettingsEntity copyWith({
    String? languageCode,
    bool? isDarkMode,
    String? storeName,
    String? receiptFootnote,
    Map<String, List<String>>? customBindings,
    bool? taxEnabled,
    int? taxPercent,
    bool? autoPrintEnabled,
    int? orderCounter,
    String? lastOrderDate,
    String? exportDirectoryPath,
    bool? saveReceiptAsImage,
    String? storeAddress,
    String? storePhoneNumber,
    String? logoSvgPath,
    String? logoSvgData,
    String? receiptPrinterName,
    String? barcodePrinterName,
    String? barcodeActionPreference,
  }) {
    return AppSettingsEntity(
      languageCode: languageCode ?? this.languageCode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      storeName: storeName ?? this.storeName,
      receiptFootnote: receiptFootnote ?? this.receiptFootnote,
      customBindings: customBindings ?? this.customBindings,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxPercent: taxPercent ?? this.taxPercent,
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      orderCounter: orderCounter ?? this.orderCounter,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      exportDirectoryPath: exportDirectoryPath ?? this.exportDirectoryPath,
      saveReceiptAsImage: saveReceiptAsImage ?? this.saveReceiptAsImage,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhoneNumber: storePhoneNumber ?? this.storePhoneNumber,
      logoSvgPath: logoSvgPath ?? this.logoSvgPath,
      logoSvgData: logoSvgData ?? this.logoSvgData,
      receiptPrinterName: receiptPrinterName ?? this.receiptPrinterName,
      barcodePrinterName: barcodePrinterName ?? this.barcodePrinterName,
      barcodeActionPreference: barcodeActionPreference ?? this.barcodeActionPreference,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsEntity &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode &&
          isDarkMode == other.isDarkMode &&
          storeName == other.storeName &&
          receiptFootnote == other.receiptFootnote &&
          customBindings == other.customBindings &&
          taxEnabled == other.taxEnabled &&
          taxPercent == other.taxPercent &&
          autoPrintEnabled == other.autoPrintEnabled &&
          orderCounter == other.orderCounter &&
          lastOrderDate == other.lastOrderDate &&
          exportDirectoryPath == other.exportDirectoryPath &&
          saveReceiptAsImage == other.saveReceiptAsImage &&
          storeAddress == other.storeAddress &&
          storePhoneNumber == other.storePhoneNumber &&
          logoSvgPath == other.logoSvgPath &&
          logoSvgData == other.logoSvgData &&
          receiptPrinterName == other.receiptPrinterName &&
          barcodePrinterName == other.barcodePrinterName &&
          barcodeActionPreference == other.barcodeActionPreference;

  @override
  int get hashCode =>
      languageCode.hashCode ^
      isDarkMode.hashCode ^
      storeName.hashCode ^
      receiptFootnote.hashCode ^
      customBindings.hashCode ^
      taxEnabled.hashCode ^
      taxPercent.hashCode ^
      autoPrintEnabled.hashCode ^
      orderCounter.hashCode ^
      lastOrderDate.hashCode ^
      exportDirectoryPath.hashCode ^
      saveReceiptAsImage.hashCode ^
      storeAddress.hashCode ^
      storePhoneNumber.hashCode ^
      logoSvgPath.hashCode ^
      logoSvgData.hashCode ^
      receiptPrinterName.hashCode ^
      barcodePrinterName.hashCode ^
      barcodeActionPreference.hashCode;
}
