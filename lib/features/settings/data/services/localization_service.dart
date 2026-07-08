class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    'ar': {
      'appTitle': 'المكتبة - نظام نقاط البيع',
      'settings': 'الإعدادات',
      'general': 'عام',
      'appearance': 'المظهر',
      'localization': 'اللغة',
      'storeName': 'اسم المتجر',
      'receiptFootnote': 'تذييل الفاتورة',
      'darkMode': 'الوضع الليلي',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'الإنجليزية',
      'lightMode': 'واضح',
      'save': 'حفظ',
      'cancel': 'إلغاء',
    },
    'en': {
      'appTitle': 'Al-Maktaba - POS System',
      'settings': 'Settings',
      'general': 'General',
      'appearance': 'Appearance',
      'localization': 'Localization',
      'storeName': 'Store Name',
      'receiptFootnote': 'Receipt Footnote',
      'darkMode': 'Dark Mode',
      'language': 'Language',
      'arabic': 'Arabic',
      'english': 'English',
      'lightMode': 'Light',
      'save': 'Save',
      'cancel': 'Cancel',
    },
  };

  static const String _defaultLanguage = 'en';

  List<String> get supportedLanguages => _translations.keys.toList();

  String translate(String key, {String? languageCode}) {
    final lang = languageCode ?? _defaultLanguage;
    final langMap = _translations[lang];
    if (langMap == null) return '{$key}';
    return langMap[key] ?? '{$key}';
  }

  String? currentLocale([String? languageCode]) {
    final lang = languageCode ?? _defaultLanguage;
    if (_translations.containsKey(lang)) return lang;
    return _defaultLanguage;
  }
}
