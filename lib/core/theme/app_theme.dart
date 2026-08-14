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

  static const RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  static ThemeData get light => _base(
    brightness: Brightness.light,
    scaffold: _lightBg,
    card: _lightCard,
    border: _lightBorder,
  );

  static ThemeData get dark => _base(
    brightness: Brightness.dark,
    scaffold: _darkBg,
    card: _darkCard,
    border: _darkBorder,
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color border,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: card,
        elevation: 1,
        shape: _buttonShape,
      ),
      dividerColor: border,
      fontFamily: 'Cairo',
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: _buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: _buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: _buttonShape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: _buttonShape),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: _buttonShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: _buttonShape,
        ),
      ),
    );
  }
}
