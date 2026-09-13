// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cashier_system/core/backend/themes/theme_manager.dart';
import 'package:cashier_system/core/business/business_type.dart';

void main() {
  group('ThemeManager', () {
    late ThemeManager themeManager;

    setUp(() {
      themeManager = ThemeManager();
    });

    test('initializes with Modern Slate theme by default', () {
      expect(themeManager.currentTheme, isA<ThemeData>());
      expect(themeManager.currentTheme.brightness, equals(Brightness.light));
      expect(themeManager.currentTheme.colorScheme.primary, equals(const Color(0xFF6B7B8D)));
    });

    test('loads Modern Slate theme correctly', () {
      themeManager.loadTheme('Modern Slate');
      expect(themeManager.currentTheme.brightness, equals(Brightness.light));
      expect(themeManager.currentTheme.colorScheme.primary, equals(const Color(0xFF6B7B8D)));
      expect(themeManager.currentTheme.colorScheme.secondary, equals(const Color(0xFF8D99A1)));
    });

    test('loads High-Contrast Dark Emerald theme correctly', () {
      themeManager.loadTheme('High-Contrast Dark Emerald');
      expect(themeManager.currentTheme.brightness, equals(Brightness.dark));
      expect(themeManager.currentTheme.colorScheme.primary, equals(const Color(0xFF00C853)));
      expect(themeManager.currentTheme.colorScheme.secondary, equals(const Color(0xFF00A044)));
    });

    test('loads Warm Espresso & Sand theme correctly', () {
      themeManager.loadTheme('Warm Espresso & Sand');
      expect(themeManager.currentTheme.brightness, equals(Brightness.light));
      expect(themeManager.currentTheme.colorScheme.primary, equals(const Color(0xFF8B5A2B)));
      expect(themeManager.currentTheme.colorScheme.secondary, equals(const Color(0xFFB8860B)));
    });

    test('loads Industrial Blue theme correctly', () {
      themeManager.loadTheme('Industrial Blue');
      expect(themeManager.currentTheme.brightness, equals(Brightness.light));
      expect(themeManager.currentTheme.colorScheme.primary, equals(const Color(0xFF2C3E50)));
      expect(themeManager.currentTheme.colorScheme.secondary, equals(const Color(0xFF34495E)));
    });

    test('falls back to light theme for unknown theme name', () {
      themeManager.loadTheme('Unknown Theme');
      expect(themeManager.currentTheme.brightness, equals(Brightness.light));
    });

    group('Receipt Styles', () {
      test('Modern Slate has 2 receipt styles', () {
        themeManager.loadTheme('Modern Slate');
        final styles = themeManager.getReceiptStyles();
        expect(styles.length, equals(2));
        expect(styles[0].name, isNotEmpty);
        expect(styles[1].name, isNotEmpty);
      });

      test('High-Contrast Dark Emerald has 2 receipt styles', () {
        themeManager.loadTheme('High-Contrast Dark Emerald');
        final styles = themeManager.getReceiptStyles();
        expect(styles.length, equals(2));
      });

      test('Warm Espresso & Sand has 2 receipt styles', () {
        themeManager.loadTheme('Warm Espresso & Sand');
        final styles = themeManager.getReceiptStyles();
        expect(styles.length, equals(2));
      });

      test('Industrial Blue has 2 receipt styles', () {
        themeManager.loadTheme('Industrial Blue');
        final styles = themeManager.getReceiptStyles();
        expect(styles.length, equals(2));
      });
    });

    group('Invoice Styles', () {
      test('Modern Slate has 2 invoice styles', () {
        themeManager.loadTheme('Modern Slate');
        final styles = themeManager.getInvoiceStyles();
        expect(styles.length, equals(2));
      });

      test('High-Contrast Dark Emerald has 2 invoice styles', () {
        themeManager.loadTheme('High-Contrast Dark Emerald');
        final styles = themeManager.getInvoiceStyles();
        expect(styles.length, equals(2));
      });

      test('Warm Espresso & Sand has 2 invoice styles', () {
        themeManager.loadTheme('Warm Espresso & Sand');
        final styles = themeManager.getInvoiceStyles();
        expect(styles.length, equals(2));
      });

      test('Industrial Blue has 2 invoice styles', () {
        themeManager.loadTheme('Industrial Blue');
        final styles = themeManager.getInvoiceStyles();
        expect(styles.length, equals(2));
      });
    });

    group('Export Styles', () {
      test('Modern Slate has 2 export styles', () {
        themeManager.loadTheme('Modern Slate');
        final styles = themeManager.getExportStyles();
        expect(styles.length, equals(2));
      });

      test('High-Contrast Dark Emerald has 2 export styles', () {
        themeManager.loadTheme('High-Contrast Dark Emerald');
        final styles = themeManager.getExportStyles();
        expect(styles.length, equals(2));
      });

      test('Warm Espresso & Sand has 2 export styles', () {
        themeManager.loadTheme('Warm Espresso & Sand');
        final styles = themeManager.getExportStyles();
        expect(styles.length, equals(2));
      });

      test('Industrial Blue has 2 export styles', () {
        themeManager.loadTheme('Industrial Blue');
        final styles = themeManager.getExportStyles();
        expect(styles.length, equals(2));
      });
    });

    group('Recommended Badges', () {
      test('returns recommended badge for retail business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.retail);
        expect(badge, isNotNull);
        expect(badge.themeName, isNotEmpty);
      });

      test('returns recommended badge for cafe business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.cafe);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for restaurant business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.restaurant);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for playstation business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.playstation);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for supermarket business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.supermarket);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for clothes business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.clothes);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for pharmacy business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.pharmacy);
        expect(badge, isNotNull);
      });

      test('returns recommended badge for piastary business type', () {
        final badge = themeManager.getRecommendedBadge(BusinessType.piastary);
        expect(badge, isNotNull);
      });
    });
  });
}