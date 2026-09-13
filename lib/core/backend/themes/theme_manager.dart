// Copyright (c) 2024 Daftari POS. All rights reserved.

library cashier_system.core.backend.themes.theme_manager;

/// Theme manager for Daftari POS system.
///
/// Manages 4 themes (Modern Slate, High-Contrast Dark Emerald, Warm Espresso & Sand, Industrial Blue)
/// with 2 receipt/invoice/export styles each, and recommended badges by business type.
import 'package:flutter/material.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'modern_slate.dart';
import 'high_contrast_dark_emerald.dart';
import 'warm_espresso_sand.dart';
import 'industrial_blue.dart';

/// Represents a receipt printing style configuration.
class ReceiptStyle {
  final String name;
  final String description;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showLogo;
  final bool showQRCode;
  final bool compactMode;
  final EdgeInsets margins;

  const ReceiptStyle({
    required this.name,
    required this.description,
    required this.fontSize,
    required this.fontWeight,
    required this.showLogo,
    required this.showQRCode,
    required this.compactMode,
    required this.margins,
  });
}

/// Represents an invoice style configuration.
class InvoiceStyle {
  final String name;
  final String description;
  final bool showHeader;
  final bool showFooter;
  final bool showItemDetails;
  final bool showTaxBreakdown;
  final bool landscape;
  final EdgeInsets margins;

  const InvoiceStyle({
    required this.name,
    required this.description,
    required this.showHeader,
    required this.showFooter,
    required this.showItemDetails,
    required this.showTaxBreakdown,
    required this.landscape,
    required this.margins,
  });
}

/// Represents an export style configuration.
class ExportStyle {
  final String name;
  final String description;
  final String format; // 'pdf', 'excel', 'csv'
  final bool includeHeader;
  final bool includeSummary;
  final bool includeItemDetails;
  final bool landscape;

  const ExportStyle({
    required this.name,
    required this.description,
    required this.format,
    required this.includeHeader,
    required this.includeSummary,
    required this.includeItemDetails,
    required this.landscape,
  });
}

/// Represents a recommended theme badge for a business type.
class RecommendedBadge {
  final String themeName;
  final String badgeText;
  final Color badgeColor;
  final String reason;

  const RecommendedBadge({
    required this.themeName,
    required this.badgeText,
    required this.badgeColor,
    required this.reason,
  });
}

class ThemeManager {
  /// Current theme data.
  ThemeData currentTheme = ThemeData.light();

  /// Current theme name.
  String _currentThemeName = 'Modern Slate';

  /// Default theme loading.
  ThemeManager() {
    currentTheme = _loadTheme('Modern Slate');
  }

  /// Get current theme name.
  String get currentThemeName => _currentThemeName;

  /// Load a theme by name.
  ThemeData loadTheme(String themeName) {
    currentTheme = _loadTheme(themeName);
    _currentThemeName = themeName;
    return currentTheme;
  }

  ThemeData _loadTheme(String themeName) {
    switch (themeName) {
      case 'Modern Slate':
        return ModernSlateTheme.build();
      case 'High-Contrast Dark Emerald':
        return HighContrastDarkEmeraldTheme.build();
      case 'Warm Espresso & Sand':
        return WarmEspressoSandTheme.build();
      case 'Industrial Blue':
        return IndustrialBlueTheme.build();
      default:
        return ThemeData.light();
    }
  }

  /// Get available theme names.
  List<String> get availableThemes => [
    'Modern Slate',
    'High-Contrast Dark Emerald',
    'Warm Espresso & Sand',
    'Industrial Blue',
  ];

  /// Get receipt styles for current theme (2 styles per theme).
  List<ReceiptStyle> getReceiptStyles() {
    switch (_currentThemeName) {
      case 'Modern Slate':
        return [
          const ReceiptStyle(
            name: 'Standard',
            description: 'Clean standard receipt with logo and QR code',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            showLogo: true,
            showQRCode: true,
            compactMode: false,
            margins: EdgeInsets.all(16),
          ),
          const ReceiptStyle(
            name: 'Compact',
            description: 'Compact receipt for high-volume printing',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            showLogo: false,
            showQRCode: false,
            compactMode: true,
            margins: EdgeInsets.all(8),
          ),
        ];
      case 'High-Contrast Dark Emerald':
        return [
          const ReceiptStyle(
            name: 'High Contrast',
            description: 'High contrast receipt for accessibility',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            showLogo: true,
            showQRCode: true,
            compactMode: false,
            margins: EdgeInsets.all(16),
          ),
          const ReceiptStyle(
            name: 'Minimal',
            description: 'Minimal high-contrast receipt',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            showLogo: false,
            showQRCode: false,
            compactMode: true,
            margins: EdgeInsets.all(12),
          ),
        ];
      case 'Warm Espresso & Sand':
        return [
          const ReceiptStyle(
            name: 'Classic',
            description: 'Warm classic receipt with branding',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            showLogo: true,
            showQRCode: true,
            compactMode: false,
            margins: EdgeInsets.all(16),
          ),
          const ReceiptStyle(
            name: 'Elegant',
            description: 'Elegant receipt with refined typography',
            fontSize: 11,
            fontWeight: FontWeight.w300,
            showLogo: true,
            showQRCode: false,
            compactMode: false,
            margins: EdgeInsets.all(20),
          ),
        ];
      case 'Industrial Blue':
        return [
          const ReceiptStyle(
            name: 'Technical',
            description: 'Technical receipt with detailed info',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            showLogo: true,
            showQRCode: true,
            compactMode: false,
            margins: EdgeInsets.all(16),
          ),
          const ReceiptStyle(
            name: 'Data Dense',
            description: 'Data-dense receipt for industrial use',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            showLogo: false,
            showQRCode: true,
            compactMode: true,
            margins: EdgeInsets.all(10),
          ),
        ];
      default:
        return [
          const ReceiptStyle(
            name: 'Default',
            description: 'Default receipt style',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            showLogo: true,
            showQRCode: true,
            compactMode: false,
            margins: EdgeInsets.all(16),
          ),
          const ReceiptStyle(
            name: 'Compact',
            description: 'Compact receipt style',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            showLogo: false,
            showQRCode: false,
            compactMode: true,
            margins: EdgeInsets.all(8),
          ),
        ];
    }
  }

  /// Get invoice styles for current theme (2 styles per theme).
  List<InvoiceStyle> getInvoiceStyles() {
    switch (_currentThemeName) {
      case 'Modern Slate':
        return [
          const InvoiceStyle(
            name: 'Professional',
            description: 'Professional invoice with full details',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: false,
            margins: EdgeInsets.all(24),
          ),
          const InvoiceStyle(
            name: 'Simple',
            description: 'Simple invoice for quick billing',
            showHeader: true,
            showFooter: false,
            showItemDetails: true,
            showTaxBreakdown: false,
            landscape: false,
            margins: EdgeInsets.all(16),
          ),
        ];
      case 'High-Contrast Dark Emerald':
        return [
          const InvoiceStyle(
            name: 'Accessible',
            description: 'High contrast accessible invoice',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: false,
            margins: EdgeInsets.all(24),
          ),
          const InvoiceStyle(
            name: 'Large Print',
            description: 'Large print invoice for visibility',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: true,
            margins: EdgeInsets.all(32),
          ),
        ];
      case 'Warm Espresso & Sand':
        return [
          const InvoiceStyle(
            name: 'Elegant',
            description: 'Elegant invoice with warm tones',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: false,
            margins: EdgeInsets.all(28),
          ),
          const InvoiceStyle(
            name: 'Boutique',
            description: 'Boutique-style invoice for retail',
            showHeader: true,
            showFooter: true,
            showItemDetails: false,
            showTaxBreakdown: false,
            landscape: false,
            margins: EdgeInsets.all(20),
          ),
        ];
      case 'Industrial Blue':
        return [
          const InvoiceStyle(
            name: 'Technical',
            description: 'Technical invoice with full specifications',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: true,
            margins: EdgeInsets.all(24),
          ),
          const InvoiceStyle(
            name: 'Work Order',
            description: 'Work order style for service businesses',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: false,
            landscape: false,
            margins: EdgeInsets.all(20),
          ),
        ];
      default:
        return [
          const InvoiceStyle(
            name: 'Standard',
            description: 'Standard invoice',
            showHeader: true,
            showFooter: true,
            showItemDetails: true,
            showTaxBreakdown: true,
            landscape: false,
            margins: EdgeInsets.all(24),
          ),
          const InvoiceStyle(
            name: 'Simple',
            description: 'Simple invoice',
            showHeader: true,
            showFooter: false,
            showItemDetails: true,
            showTaxBreakdown: false,
            landscape: false,
            margins: EdgeInsets.all(16),
          ),
        ];
    }
  }

  /// Get export styles for current theme (2 styles per theme).
  List<ExportStyle> getExportStyles() {
    switch (_currentThemeName) {
      case 'Modern Slate':
        return [
          const ExportStyle(
            name: 'PDF Report',
            description: 'Full PDF report with headers and summaries',
            format: 'pdf',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: false,
          ),
          const ExportStyle(
            name: 'Excel Export',
            description: 'Excel spreadsheet for data analysis',
            format: 'excel',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: true,
          ),
        ];
      case 'High-Contrast Dark Emerald':
        return [
          const ExportStyle(
            name: 'Accessible PDF',
            description: 'High contrast accessible PDF export',
            format: 'pdf',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: false,
          ),
          const ExportStyle(
            name: 'CSV Data',
            description: 'Raw CSV data for processing',
            format: 'csv',
            includeHeader: true,
            includeSummary: false,
            includeItemDetails: true,
            landscape: false,
          ),
        ];
      case 'Warm Espresso & Sand':
        return [
          const ExportStyle(
            name: 'Branded PDF',
            description: 'Branded PDF with warm theme',
            format: 'pdf',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: false,
          ),
          const ExportStyle(
            name: 'Excel Summary',
            description: 'Excel with summary sheets',
            format: 'excel',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: false,
            landscape: false,
          ),
        ];
      case 'Industrial Blue':
        return [
          const ExportStyle(
            name: 'Technical PDF',
            description: 'Technical PDF with full specifications',
            format: 'pdf',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: true,
          ),
          const ExportStyle(
            name: 'CSV Export',
            description: 'CSV for system integration',
            format: 'csv',
            includeHeader: true,
            includeSummary: false,
            includeItemDetails: true,
            landscape: false,
          ),
        ];
      default:
        return [
          const ExportStyle(
            name: 'PDF Export',
            description: 'Standard PDF export',
            format: 'pdf',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: false,
          ),
          const ExportStyle(
            name: 'Excel Export',
            description: 'Standard Excel export',
            format: 'excel',
            includeHeader: true,
            includeSummary: true,
            includeItemDetails: true,
            landscape: false,
          ),
        ];
    }
  }

  /// Get recommended badge for a business type.
  RecommendedBadge getRecommendedBadge(BusinessType businessType) {
    switch (businessType) {
      case BusinessType.retail:
        return const RecommendedBadge(
          themeName: 'Modern Slate',
          badgeText: '✨ Recommended for Retail',
          badgeColor: Color(0xFF6B7B8D),
          reason: 'Clean, professional look suits retail environments',
        );
      case BusinessType.supermarket:
        return const RecommendedBadge(
          themeName: 'Industrial Blue',
          badgeText: '✨ Recommended for Supermarket',
          badgeColor: Color(0xFF2C3E50),
          reason: 'High contrast and data density for high-volume scanning',
        );
      case BusinessType.cafe:
        return const RecommendedBadge(
          themeName: 'Warm Espresso & Sand',
          badgeText: '✨ Recommended for Cafe',
          badgeColor: Color(0xFF8B5A2B),
          reason: 'Warm, inviting atmosphere matches cafe ambiance',
        );
      case BusinessType.restaurant:
        return const RecommendedBadge(
          themeName: 'Warm Espresso & Sand',
          badgeText: '✨ Recommended for Restaurant',
          badgeColor: Color(0xFF8B5A2B),
          reason: 'Elegant warm tones complement dining experience',
        );
      case BusinessType.playstation:
        return const RecommendedBadge(
          themeName: 'High-Contrast Dark Emerald',
          badgeText: '✨ Recommended for PlayStation',
          badgeColor: Color(0xFF00C853),
          reason: 'Dark mode reduces eye strain during gaming sessions',
        );
      case BusinessType.clothes:
        return const RecommendedBadge(
          themeName: 'Modern Slate',
          badgeText: '✨ Recommended for Clothing',
          badgeColor: Color(0xFF6B7B8D),
          reason: 'Modern, stylish appearance fits fashion retail',
        );
      case BusinessType.pharmacy:
        return const RecommendedBadge(
          themeName: 'Industrial Blue',
          badgeText: '✨ Recommended for Pharmacy',
          badgeColor: Color(0xFF2C3E50),
          reason: 'Professional, trustworthy blue conveys reliability',
        );
      case BusinessType.piastary:
        return const RecommendedBadge(
          themeName: 'Warm Espresso & Sand',
          badgeText: '✨ Recommended for Piastary',
          badgeColor: Color(0xFF8B5A2B),
          reason: 'Warm artisan feel matches baked goods atmosphere',
        );
    }
  }
}
