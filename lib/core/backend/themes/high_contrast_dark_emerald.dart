// Copyright (c) 2024 Daftari POS. All rights reserved.

library cashier_system.core.backend.themes.high_contrast_dark_emerald;

/// High Contrast Dark Emerald theme implementation.
import 'package:flutter/material.dart';

class HighContrastDarkEmeraldTheme {
  /// Build the High Contrast Dark Emerald theme data.
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: const Color(0xFF111111),
        primary: const Color(0xFF00C853),
        onPrimary: Colors.white,
        secondary: const Color(0xFF00A044),
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
      ),
    );
  }
}
