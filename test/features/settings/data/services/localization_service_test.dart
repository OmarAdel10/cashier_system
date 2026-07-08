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
    test('should provide settings tab labels in Arabic', () {
      expect(service.translate('general', languageCode: 'ar'), 'عام');
      expect(service.translate('appearance', languageCode: 'ar'), 'المظهر');
      expect(service.translate('localization', languageCode: 'ar'), 'اللغة');
    });

    test('should provide settings tab labels in English', () {
      expect(service.translate('general', languageCode: 'en'), 'General');
      expect(service.translate('appearance', languageCode: 'en'), 'Appearance');
      expect(service.translate('localization', languageCode: 'en'), 'Localization');
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
