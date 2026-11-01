import 'package:flutter/material.dart';

class AppButtons {
  AppButtons._();

  static ButtonStyle danger(ColorScheme scheme) => FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );

  static ButtonStyle dangerText(ColorScheme scheme) =>
      TextButton.styleFrom(foregroundColor: scheme.error);

  static ButtonStyle dangerElevated(ColorScheme scheme) =>
      ElevatedButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );
}
