class AppSettingsEntity {
  final String languageCode;
  final bool isDarkMode;
  final String storeName;
  final String receiptFootnote;

  const AppSettingsEntity({
    this.languageCode = 'ar',
    this.isDarkMode = false,
    this.storeName = '',
    this.receiptFootnote = '',
  });

  bool get isRtl => languageCode == 'ar';

  AppSettingsEntity copyWith({
    String? languageCode,
    bool? isDarkMode,
    String? storeName,
    String? receiptFootnote,
  }) {
    return AppSettingsEntity(
      languageCode: languageCode ?? this.languageCode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      storeName: storeName ?? this.storeName,
      receiptFootnote: receiptFootnote ?? this.receiptFootnote,
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
          receiptFootnote == other.receiptFootnote;

  @override
  int get hashCode =>
      languageCode.hashCode ^
      isDarkMode.hashCode ^
      storeName.hashCode ^
      receiptFootnote.hashCode;
}
