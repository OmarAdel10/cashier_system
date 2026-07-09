import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';

void main() {
  late LocalizationService service;

  setUp(() {
    service = LocalizationService();
  });

  group('supportedLanguages', () {
    test('should return Arabic and English', () {
      final languages = service.supportedLanguages;
      expect(languages, contains('ar'));
      expect(languages, contains('en'));
    });
  });

  group('translate', () {
    test('should return Arabic translation when languageCode is ar', () {
      final result = service.translate('appTitle', languageCode: 'ar');
      expect(result, 'المكتبة - نظام نقاط البيع');
    });

    test('should return English translation when languageCode is en', () {
      final result = service.translate('appTitle', languageCode: 'en');
      expect(result, 'Al-Maktaba - POS System');
    });

    test('should return English translation by default', () {
      final result = service.translate('appTitle');
      expect(result, 'Al-Maktaba - POS System');
    });

    test('should return key wrapped in brackets for missing keys', () {
      final result = service.translate('nonexistent_key', languageCode: 'ar');
      expect(result, '{nonexistent_key}');
    });

    test('should return key wrapped in brackets for unsupported language', () {
      final result = service.translate('appTitle', languageCode: 'fr');
      expect(result, '{appTitle}');
    });
  });

  group('settings translations', () {
    test('should provide section labels in Arabic', () {
      expect(service.translate('settings', languageCode: 'ar'), 'الإعدادات');
      expect(service.translate('general', languageCode: 'ar'), 'عام');
      expect(service.translate('appearance', languageCode: 'ar'), 'المظهر');
      expect(service.translate('localization', languageCode: 'ar'), 'اللغة');
    });

    test('should provide section labels in English', () {
      expect(service.translate('settings', languageCode: 'en'), 'Settings');
      expect(service.translate('general', languageCode: 'en'), 'General');
      expect(service.translate('appearance', languageCode: 'en'), 'Appearance');
      expect(service.translate('localization', languageCode: 'en'), 'Localization');
    });

    test('should provide hint labels in Arabic', () {
      expect(service.translate('storeNameHint', languageCode: 'ar'), 'أدخل اسم المتجر');
      expect(service.translate('receiptFootnoteHint', languageCode: 'ar'), 'أدخل رسالة تذييل الفاتورة');
    });

    test('should provide hint labels in English', () {
      expect(service.translate('storeNameHint', languageCode: 'en'), 'Enter store name');
      expect(service.translate('receiptFootnoteHint', languageCode: 'en'), 'Enter receipt footer message');
    });

    test('should provide theme status labels in Arabic', () {
      expect(service.translate('darkModeActive', languageCode: 'ar'), 'الوضع الليلي نشط');
      expect(service.translate('lightModeActive', languageCode: 'ar'), 'الوضع النهاري نشط');
    });

    test('should provide theme status labels in English', () {
      expect(service.translate('darkModeActive', languageCode: 'en'), 'Dark theme active');
      expect(service.translate('lightModeActive', languageCode: 'en'), 'Light theme active');
    });

    test('should provide field labels in Arabic', () {
      expect(service.translate('storeName', languageCode: 'ar'), 'اسم المتجر');
      expect(service.translate('receiptFootnote', languageCode: 'ar'), 'تذييل الفاتورة');
      expect(service.translate('darkMode', languageCode: 'ar'), 'الوضع الليلي');
    });

    test('should provide field labels in English', () {
      expect(service.translate('storeName', languageCode: 'en'), 'Store Name');
      expect(service.translate('receiptFootnote', languageCode: 'en'), 'Receipt Footnote');
      expect(service.translate('darkMode', languageCode: 'en'), 'Dark Mode');
    });

    test('should provide language labels in Arabic', () {
      expect(service.translate('arabic', languageCode: 'ar'), 'العربية');
      expect(service.translate('english', languageCode: 'ar'), 'الإنجليزية');
    });

    test('should provide language labels in English', () {
      expect(service.translate('arabic', languageCode: 'en'), 'Arabic');
      expect(service.translate('english', languageCode: 'en'), 'English');
    });

    test('should provide directionality hints in Arabic', () {
      expect(service.translate('rtlHint', languageCode: 'ar'), contains('اليمين'));
      expect(service.translate('ltrHint', languageCode: 'ar'), contains('اليسار'));
    });

    test('should provide directionality hints in English', () {
      expect(service.translate('rtlHint', languageCode: 'en'), contains('RTL'));
      expect(service.translate('ltrHint', languageCode: 'en'), contains('LTR'));
    });
  });

  group('navigation labels', () {
    test('should provide nav labels in Arabic', () {
      expect(service.translate('navCheckout', languageCode: 'ar'), 'الدفع');
      expect(service.translate('navInventory', languageCode: 'ar'), 'المخزون');
      expect(service.translate('navSales', languageCode: 'ar'), 'المبيعات');
      expect(service.translate('navSettings', languageCode: 'ar'), 'الإعدادات');
    });

    test('should provide nav labels in English', () {
      expect(service.translate('navCheckout', languageCode: 'en'), 'Checkout');
      expect(service.translate('navInventory', languageCode: 'en'), 'Inventory');
      expect(service.translate('navSales', languageCode: 'en'), 'Sales');
      expect(service.translate('navSettings', languageCode: 'en'), 'Settings');
    });
  });

  group('receipt tower labels', () {
    test('should provide tower labels in Arabic', () {
      expect(service.translate('receiptTower', languageCode: 'ar'), 'الفاتورة');
      expect(service.translate('receiptPlaceholder', languageCode: 'ar'), contains('الفاتورة'));
      expect(service.translate('comingSoon', languageCode: 'ar'), 'قريباً');
    });

    test('should provide tower labels in English', () {
      expect(service.translate('receiptTower', languageCode: 'en'), 'Receipt');
      expect(service.translate('receiptPlaceholder', languageCode: 'en'), contains('receipt'));
      expect(service.translate('comingSoon', languageCode: 'en'), 'Coming Soon');
    });
  });

  group('currentLocale', () {
    test('should return Arabic locale string for ar', () {
      expect(service.currentLocale('ar'), 'ar');
    });

    test('should return English locale string for en', () {
      expect(service.currentLocale('en'), 'en');
    });

    test('should return English for unsupported language', () {
      expect(service.currentLocale('fr'), 'en');
    });

    test('should return English by default', () {
      expect(service.currentLocale(null), 'en');
      expect(service.currentLocale(''), 'en');
    });
  });
}
