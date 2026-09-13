// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Warm Espresso & Sand theme implementation.
import 'package:flutter/material.dart';

class WarmEspressoSandTheme {
  /// Build the Warm Espresso & Sand theme data.
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        surface: Colors.white,
        background: Colors.white,
        primary: const Color(0xFF8B5A2B),
        onPrimary: Colors.white,
        secondary: const Color(0xFFB8860B),
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
      ),
    );
  }
}
