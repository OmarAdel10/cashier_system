import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

void main() {
  group('AppSettingsEntity', () {
    group('defaults', () {
      test('should use default values when no arguments provided', () {
        const entity = AppSettingsEntity();

        expect(entity.languageCode, 'ar');
        expect(entity.isDarkMode, false);
        expect(entity.storeName, '');
        expect(entity.receiptFootnote, 'Thanks');
        expect(entity.businessType, 'retail');
        expect(entity.minimumGameCost, 500);
        expect(entity.isRtl, true);
      });
    });

    group('custom values', () {
      test('should store provided values', () {
        const entity = AppSettingsEntity(
          languageCode: 'en',
          isDarkMode: true,
          storeName: 'My Store',
          receiptFootnote: 'Thank you!',
        );

        expect(entity.languageCode, 'en');
        expect(entity.isDarkMode, true);
        expect(entity.storeName, 'My Store');
        expect(entity.receiptFootnote, 'Thank you!');
        expect(entity.isRtl, false);
      });

      test('should return isRtl true only for Arabic', () {
        expect(const AppSettingsEntity(languageCode: 'ar').isRtl, true);
        expect(const AppSettingsEntity(languageCode: 'en').isRtl, false);
        expect(const AppSettingsEntity(languageCode: 'fr').isRtl, false);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        const a = AppSettingsEntity(
          languageCode: 'en',
          isDarkMode: true,
          storeName: 'Store',
          receiptFootnote: 'Note',
        );
        const b = AppSettingsEntity(
          languageCode: 'en',
          isDarkMode: true,
          storeName: 'Store',
          receiptFootnote: 'Note',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('should not be equal when languageCode differs', () {
        const a = AppSettingsEntity(languageCode: 'ar');
        const b = AppSettingsEntity(languageCode: 'en');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when isDarkMode differs', () {
        const a = AppSettingsEntity(isDarkMode: false);
        const b = AppSettingsEntity(isDarkMode: true);

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when storeName differs', () {
        const a = AppSettingsEntity(storeName: 'Store A');
        const b = AppSettingsEntity(storeName: 'Store B');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when receiptFootnote differs', () {
        const a = AppSettingsEntity(receiptFootnote: 'Note A');
        const b = AppSettingsEntity(receiptFootnote: 'Note B');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when businessType differs', () {
        const a = AppSettingsEntity(businessType: 'retail');
        const b = AppSettingsEntity(businessType: 'cafe');

        expect(a, isNot(equals(b)));
      });

      test('should not be equal when minimumGameCost differs', () {
        const a = AppSettingsEntity(minimumGameCost: 500);
        const b = AppSettingsEntity(minimumGameCost: 1000);

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        const original = AppSettingsEntity(
          languageCode: 'ar',
          isDarkMode: false,
          storeName: 'Store',
          receiptFootnote: 'Note',
        );

        final modified = original.copyWith(
          languageCode: 'en',
          isDarkMode: true,
        );

        expect(modified.languageCode, 'en');
        expect(modified.isDarkMode, true);
        expect(modified.storeName, 'Store');
        expect(modified.receiptFootnote, 'Note');
      });

      test('should keep original fields when not specified', () {
        const original = AppSettingsEntity(
          languageCode: 'ar',
          isDarkMode: false,
          storeName: 'Store',
          receiptFootnote: 'Note',
        );

        final modified = original.copyWith();

        expect(modified.languageCode, 'ar');
        expect(modified.isDarkMode, false);
        expect(modified.storeName, 'Store');
        expect(modified.receiptFootnote, 'Note');
      });

      test('should update businessType with copyWith', () {
        const original = AppSettingsEntity();

        final modified = original.copyWith(businessType: 'cafe');

        expect(modified.businessType, 'cafe');
        expect(modified.minimumGameCost, 500);
      });

      test('should update minimumGameCost with copyWith', () {
        const original = AppSettingsEntity();

        final modified = original.copyWith(minimumGameCost: 1000);

        expect(modified.minimumGameCost, 1000);
        expect(modified.businessType, 'retail');
      });
    });
  });
}
