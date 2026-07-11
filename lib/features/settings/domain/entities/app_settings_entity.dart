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

  const AppSettingsEntity({
    this.languageCode = 'ar',
    this.isDarkMode = false,
    this.storeName = '',
    this.receiptFootnote = '',
    this.customBindings = const {},
    this.taxEnabled = false,
    this.taxPercent = 0,
    this.autoPrintEnabled = false,
    this.orderCounter = 0,
    this.lastOrderDate = '',
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
          lastOrderDate == other.lastOrderDate;

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
      lastOrderDate.hashCode;
}
