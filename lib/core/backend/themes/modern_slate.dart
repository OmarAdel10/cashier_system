// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Modern Slate theme implementation.
import 'package:flutter/material.dart';

class ModernSlateTheme {
  /// Build the Modern Slate theme data.
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        surface: Colors.white,
        background: Colors.white,
        primary: const Color(0xFF6B7B8D),
        onPrimary: Colors.white,
        secondary: const Color(0xFF8D99A1),
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
      ),
    );
  }
}
