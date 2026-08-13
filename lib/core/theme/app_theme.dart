import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF007ACC);
  static const Color _lightBg = Color(0xFFF5F0EB);
  static const Color _lightCard = Color(0xFFFFFDF5);
  static const Color _lightBorder = Color(0xFFE8E0D8);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkCard = Color(0xFF1E293B);
  static const Color _darkBorder = Color(0xFF334155);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: _primary,
    scaffoldBackgroundColor: _lightBg,
    cardTheme: const CardThemeData(
      color: _lightCard,
      surfaceTintColor: _lightCard,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dividerColor: _lightBorder,
    fontFamily: 'Cairo',
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: _primary,
    scaffoldBackgroundColor: _darkBg,
    cardTheme: const CardThemeData(
      color: _darkCard,
      surfaceTintColor: _darkCard,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dividerColor: _darkBorder,
    fontFamily: 'Cairo',
  );
}
