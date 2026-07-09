class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    'ar': {
      'appTitle': 'جود',
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
      'navCheckout': 'الدفع',
      'navInventory': 'المخزون',
      'navSales': 'المبيعات',
      'navSettings': 'الإعدادات',
      'receiptTower': 'الفاتورة',
      'receiptPlaceholder': 'ستظهر سلة المشتريات والفاتورة هنا',
      'comingSoon': 'قريباً',
      'state.loading.saving': 'جاري حفظ الإعدادات...',
      'state.loading.loading': 'جاري تحميل الإعدادات...',
      'state.error.save': 'تعذر حفظ التغييرات',
      'state.error.save.action': 'حاول مرة أخرى',
      'state.error.load': 'تعذر تحميل الإعدادات',
      'state.error.load.action': 'إعادة المحاولة',
      'state.empty.settings': 'لم يتم العثور على إعدادات',
    },
    'en': {
      'appTitle': 'Joud',
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
      'navCheckout': 'Checkout',
      'navInventory': 'Inventory',
      'navSales': 'Sales',
      'navSettings': 'Settings',
      'receiptTower': 'Receipt',
      'receiptPlaceholder': 'Cart & receipt will appear here',
      'comingSoon': 'Coming Soon',
      'state.loading.saving': 'Saving settings...',
      'state.loading.loading': 'Loading settings...',
      'state.error.save': 'Could not save your changes',
      'state.error.save.action': 'Try again',
      'state.error.load': 'Could not load your settings',
      'state.error.load.action': 'Retry',
      'state.empty.settings': 'No settings found',
    },
  };

  static const String _defaultLanguage = 'ar';

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
