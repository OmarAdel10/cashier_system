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
  final String? logoSvgData;
  final String? receiptPrinterName;
  final String? barcodePrinterName;
  final String barcodeActionPreference;
  final List<String> shownPaymentTypeIds;
  final String businessType;
  final int minimumGameCost;
  final bool favoritesStripEnabled;
  final bool roomsEnabled;
  final bool serviceChargeEnabled;
  final int serviceChargePercent;
  final bool minChargeEnabled;
  final int minChargePerTablePiastres;
  final bool kitchenTicketsEnabled;
  final String? kitchenPrinterName;
  final bool barTicketsEnabled;
  final String? barPrinterName;
  final bool shishaTicketsEnabled;
  final String? shishaPrinterName;

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
    this.logoSvgData,
    this.receiptPrinterName,
    this.barcodePrinterName,
    this.barcodeActionPreference = 'printDirect',
    this.shownPaymentTypeIds = const [],
    this.businessType = 'retail',
    this.minimumGameCost = 500,
    this.favoritesStripEnabled = false,
    this.roomsEnabled = false,
    this.serviceChargeEnabled = false,
    this.serviceChargePercent = 12,
    this.minChargeEnabled = false,
    this.minChargePerTablePiastres = 0,
    this.kitchenTicketsEnabled = true,
    this.kitchenPrinterName,
    this.barTicketsEnabled = true,
    this.barPrinterName,
    this.shishaTicketsEnabled = true,
    this.shishaPrinterName,
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
    String? logoSvgData,
    String? receiptPrinterName,
    String? barcodePrinterName,
    String? barcodeActionPreference,
    List<String>? shownPaymentTypeIds,
    String? businessType,
    int? minimumGameCost,
    bool? favoritesStripEnabled,
    bool? roomsEnabled,
    bool? serviceChargeEnabled,
    int? serviceChargePercent,
    bool? minChargeEnabled,
    int? minChargePerTablePiastres,
    bool? kitchenTicketsEnabled,
    String? kitchenPrinterName,
    bool? barTicketsEnabled,
    String? barPrinterName,
    bool? shishaTicketsEnabled,
    String? shishaPrinterName,
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
      logoSvgData: logoSvgData ?? this.logoSvgData,
      receiptPrinterName: receiptPrinterName ?? this.receiptPrinterName,
      barcodePrinterName: barcodePrinterName ?? this.barcodePrinterName,
      barcodeActionPreference:
          barcodeActionPreference ?? this.barcodeActionPreference,
      shownPaymentTypeIds: shownPaymentTypeIds ?? this.shownPaymentTypeIds,
      businessType: businessType ?? this.businessType,
      minimumGameCost: minimumGameCost ?? this.minimumGameCost,
      favoritesStripEnabled:
          favoritesStripEnabled ?? this.favoritesStripEnabled,
      roomsEnabled: roomsEnabled ?? this.roomsEnabled,
      serviceChargeEnabled: serviceChargeEnabled ?? this.serviceChargeEnabled,
      serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
      minChargeEnabled: minChargeEnabled ?? this.minChargeEnabled,
      minChargePerTablePiastres:
          minChargePerTablePiastres ?? this.minChargePerTablePiastres,
      kitchenTicketsEnabled:
          kitchenTicketsEnabled ?? this.kitchenTicketsEnabled,
      kitchenPrinterName: kitchenPrinterName ?? this.kitchenPrinterName,
      barTicketsEnabled: barTicketsEnabled ?? this.barTicketsEnabled,
      barPrinterName: barPrinterName ?? this.barPrinterName,
      shishaTicketsEnabled: shishaTicketsEnabled ?? this.shishaTicketsEnabled,
      shishaPrinterName: shishaPrinterName ?? this.shishaPrinterName,
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
          logoSvgData == other.logoSvgData &&
          receiptPrinterName == other.receiptPrinterName &&
          barcodePrinterName == other.barcodePrinterName &&
          barcodeActionPreference == other.barcodeActionPreference &&
          shownPaymentTypeIds == other.shownPaymentTypeIds &&
          businessType == other.businessType &&
          minimumGameCost == other.minimumGameCost &&
          favoritesStripEnabled == other.favoritesStripEnabled &&
          roomsEnabled == other.roomsEnabled &&
          serviceChargeEnabled == other.serviceChargeEnabled &&
          serviceChargePercent == other.serviceChargePercent &&
          minChargeEnabled == other.minChargeEnabled &&
          minChargePerTablePiastres == other.minChargePerTablePiastres &&
          kitchenTicketsEnabled == other.kitchenTicketsEnabled &&
          kitchenPrinterName == other.kitchenPrinterName &&
          barTicketsEnabled == other.barTicketsEnabled &&
          barPrinterName == other.barPrinterName &&
          shishaTicketsEnabled == other.shishaTicketsEnabled &&
          shishaPrinterName == other.shishaPrinterName;

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
      logoSvgData.hashCode ^
      receiptPrinterName.hashCode ^
      barcodePrinterName.hashCode ^
      barcodeActionPreference.hashCode ^
      shownPaymentTypeIds.hashCode ^
      businessType.hashCode ^
      minimumGameCost.hashCode ^
      favoritesStripEnabled.hashCode ^
      roomsEnabled.hashCode ^
      serviceChargeEnabled.hashCode ^
      serviceChargePercent.hashCode ^
      minChargeEnabled.hashCode ^
      minChargePerTablePiastres.hashCode ^
      kitchenTicketsEnabled.hashCode ^
      kitchenPrinterName.hashCode ^
      barTicketsEnabled.hashCode ^
      barPrinterName.hashCode ^
      shishaTicketsEnabled.hashCode ^
      shishaPrinterName.hashCode;
}
