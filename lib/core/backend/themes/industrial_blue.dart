// Copyright (c) 2024 Daftari POS. All rights reserved.

library;

/// Industrial Blue theme implementation.
import 'package:flutter/material.dart';

class IndustrialBlueTheme {
  /// Build the Industrial Blue theme data.
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        surface: Colors.white,
        primary: const Color(0xFF2C3E50),
        onPrimary: Colors.white,
        secondary: const Color(0xFF34495E),
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
      ),
    );
  }
}
