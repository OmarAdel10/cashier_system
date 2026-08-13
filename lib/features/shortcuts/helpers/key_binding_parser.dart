import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final Map<String, LogicalKeyboardKey> _keyMap = () {
  final map = <String, LogicalKeyboardKey>{
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
    'a': LogicalKeyboardKey.keyA,
    'b': LogicalKeyboardKey.keyB,
    'c': LogicalKeyboardKey.keyC,
    'd': LogicalKeyboardKey.keyD,
    'e': LogicalKeyboardKey.keyE,
    'f': LogicalKeyboardKey.keyF,
    'g': LogicalKeyboardKey.keyG,
    'h': LogicalKeyboardKey.keyH,
    'i': LogicalKeyboardKey.keyI,
    'j': LogicalKeyboardKey.keyJ,
    'k': LogicalKeyboardKey.keyK,
    'l': LogicalKeyboardKey.keyL,
    'm': LogicalKeyboardKey.keyM,
    'n': LogicalKeyboardKey.keyN,
    'o': LogicalKeyboardKey.keyO,
    'p': LogicalKeyboardKey.keyP,
    'q': LogicalKeyboardKey.keyQ,
    'r': LogicalKeyboardKey.keyR,
    's': LogicalKeyboardKey.keyS,
    't': LogicalKeyboardKey.keyT,
    'u': LogicalKeyboardKey.keyU,
    'v': LogicalKeyboardKey.keyV,
    'w': LogicalKeyboardKey.keyW,
    'x': LogicalKeyboardKey.keyX,
    'y': LogicalKeyboardKey.keyY,
    'z': LogicalKeyboardKey.keyZ,
  };
  return map;
}();

final Map<LogicalKeyboardKey, String> _reverseKeyMap = _keyMap.map(
  (k, v) => MapEntry(v, k),
);

bool isSupportedKey(LogicalKeyboardKey key) => _reverseKeyMap.containsKey(key);

/// Keys that are safe to bind WITHOUT a modifier.
///
/// Printable keys (digits, letters, space, enter, slash, ...) are excluded
/// because a barcode scanner injects raw HID keystrokes — a bare printable
/// binding would fire mid-scan.
final Set<LogicalKeyboardKey> _bareSafeKeys = {
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.delete,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.escape,
};

bool isBareSafeKey(LogicalKeyboardKey key) => _bareSafeKeys.contains(key);

SingleActivator parseKeyCombo(String combo, {bool includeRepeats = true}) {
  final parts = combo.split('+');
  final key = parts.last;
  final modifiers = parts
      .sublist(0, parts.length - 1)
      .map((m) => m.toLowerCase())
      .toList();
  return SingleActivator(
    _keyMap[key] ?? _keyMap[key.toLowerCase()] ?? LogicalKeyboardKey.help,
    control: modifiers.contains('ctrl'),
    alt: modifiers.contains('alt'),
    shift: modifiers.contains('shift'),
    meta: modifiers.contains('meta'),
    includeRepeats: includeRepeats,
  );
}

String buildComboString({
  required LogicalKeyboardKey key,
  bool control = false,
  bool alt = false,
  bool shift = false,
  bool meta = false,
}) {
  final parts = <String>[];
  if (control) parts.add('ctrl');
  if (alt) parts.add('alt');
  if (shift) parts.add('shift');
  if (meta) parts.add('meta');
  parts.add(_reverseKeyMap[key] ?? 'unknown');
  return parts.join('+');
}

String displayCombo(String combo) {
  return combo
      .split('+')
      .map((part) {
        switch (part) {
          case 'ctrl':
            return 'Ctrl';
          case 'alt':
            return 'Alt';
          case 'shift':
            return 'Shift';
          case 'meta':
            return 'Meta';
          case 'arrowUp':
            return '\u2191';
          case 'arrowDown':
            return '\u2193';
          case 'arrowLeft':
            return '\u2190';
          case 'arrowRight':
            return '\u2192';
          case 'delete':
            return 'Del';
          case 'space':
            return 'Space';
          case 'escape':
            return 'Esc';
          case 'enter':
            return 'Enter';
          case 'backspace':
            return 'Bksp';
          default:
            if (part.length == 1) return part.toUpperCase();
            return part[0].toUpperCase() + part.substring(1);
        }
      })
      .join('+');
}
