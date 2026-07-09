class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    'ar': {
      'appTitle': 'المكتبة - نظام نقاط البيع',
      'settings': 'الإعدادات',
      'general': 'عام',
      'appearance': 'المظهر',
      'localization': 'اللغة',
      'storeName': 'اسم المتجر',
      'storeNameHint': 'أدخل اسم المتجر',
      'receiptFootnote': 'تذييل الفاتورة',
      'receiptFootnoteHint': 'أدخل رسالة تذييل الفاتورة',
      'darkMode': 'الوضع الليلي',
      'darkModeActive': 'الوضع الليلي نشط',
      'lightModeActive': 'الوضع النهاري نشط',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'الإنجليزية',
      'lightMode': 'واضح',
      'rtlHint': 'الوضع العربي: ستتم محاذاة الواجهة من اليمين إلى اليسار',
      'ltrHint': 'الوضع الإنجليزي: ستتم محاذاة الواجهة من اليسار إلى اليمين',
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
      'storeNameHint': 'Enter store name',
      'receiptFootnote': 'Receipt Footnote',
      'receiptFootnoteHint': 'Enter receipt footer message',
      'darkMode': 'Dark Mode',
      'darkModeActive': 'Dark theme active',
      'lightModeActive': 'Light theme active',
      'language': 'Language',
      'arabic': 'Arabic',
      'english': 'English',
      'lightMode': 'Light',
      'rtlHint': 'Arabic mode: interface will flip to RTL layout',
      'ltrHint': 'English mode: interface will use LTR layout',
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
