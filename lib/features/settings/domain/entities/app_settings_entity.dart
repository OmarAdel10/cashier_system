class AppSettingsEntity {
  final String languageCode;
  final bool isDarkMode;

  const AppSettingsEntity({
    this.languageCode = 'ar',
    this.isDarkMode = false,
  });

  bool get isRtl => languageCode == 'ar';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsEntity &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode &&
          isDarkMode == other.isDarkMode;

  @override
  int get hashCode => languageCode.hashCode ^ isDarkMode.hashCode;
}
