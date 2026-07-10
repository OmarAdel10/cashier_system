import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final Map<String, LogicalKeyboardKey> _keyMap = {
  'f1': LogicalKeyboardKey.f1,
  'f2': LogicalKeyboardKey.f2,
  'f3': LogicalKeyboardKey.f3,
  'f4': LogicalKeyboardKey.f4,
  'f5': LogicalKeyboardKey.f5,
  'f6': LogicalKeyboardKey.f6,
  'f7': LogicalKeyboardKey.f7,
  'f8': LogicalKeyboardKey.f8,
  'f9': LogicalKeyboardKey.f9,
  'f10': LogicalKeyboardKey.f10,
  'f11': LogicalKeyboardKey.f11,
  'f12': LogicalKeyboardKey.f12,
  'space': LogicalKeyboardKey.space,
  'enter': LogicalKeyboardKey.enter,
  'escape': LogicalKeyboardKey.escape,
  'delete': LogicalKeyboardKey.delete,
  'backspace': LogicalKeyboardKey.backspace,
  'arrowUp': LogicalKeyboardKey.arrowUp,
  'arrowDown': LogicalKeyboardKey.arrowDown,
  'arrowLeft': LogicalKeyboardKey.arrowLeft,
  'arrowRight': LogicalKeyboardKey.arrowRight,
  '/': LogicalKeyboardKey.slash,
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

SingleActivator parseKeyCombo(String combo) {
  final parts = combo.toLowerCase().split('+');
  final key = parts.last;
  final modifiers = parts.sublist(0, parts.length - 1);
  return SingleActivator(
    _keyMap[key] ?? LogicalKeyboardKey.help,
    control: modifiers.contains('ctrl'),
    alt: modifiers.contains('alt'),
    shift: modifiers.contains('shift'),
    meta: modifiers.contains('meta'),
  );
}
