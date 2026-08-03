import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/shortcuts/helpers/key_binding_parser.dart';

void main() {
  group('parseKeyCombo', () {
    test('parses simple key without modifiers', () {
      final result = parseKeyCombo('a');
      expect(result.trigger, LogicalKeyboardKey.keyA);
      expect(result.control, false);
      expect(result.alt, false);
      expect(result.shift, false);
      expect(result.meta, false);
    });

    test('parses ctrl+key combo', () {
      final result = parseKeyCombo('ctrl+c');
      expect(result.trigger, LogicalKeyboardKey.keyC);
      expect(result.control, true);
      expect(result.alt, false);
      expect(result.shift, false);
    });

    test('parses ctrl+alt+key combo', () {
      final result = parseKeyCombo('ctrl+alt+delete');
      expect(result.trigger, LogicalKeyboardKey.delete);
      expect(result.control, true);
      expect(result.alt, true);
      expect(result.shift, false);
    });

    test('parses shift+key combo', () {
      final result = parseKeyCombo('shift+f1');
      expect(result.trigger, LogicalKeyboardKey.f1);
      expect(result.shift, true);
    });

    test('parses meta+key combo', () {
      final result = parseKeyCombo('meta+space');
      expect(result.trigger, LogicalKeyboardKey.space);
      expect(result.meta, true);
    });

    test('handles unknown key as help key', () {
      final result = parseKeyCombo('nonexistentKey');
      expect(result.trigger, LogicalKeyboardKey.help);
    });

    test('handles unknown key with modifier', () {
      final result = parseKeyCombo('ctrl+nonexistent');
      expect(result.trigger, LogicalKeyboardKey.help);
      expect(result.control, true);
    });

    test('is case insensitive', () {
      final lower = parseKeyCombo('ctrl+e');
      final upper = parseKeyCombo('Ctrl+E');
      expect(lower.trigger, upper.trigger);
      expect(lower.control, upper.control);
    });

    test('parses digit keys', () {
      final result = parseKeyCombo('1');
      expect(result.trigger, LogicalKeyboardKey.digit1);
    });

    test('parses function keys', () {
      final result = parseKeyCombo('f12');
      expect(result.trigger, LogicalKeyboardKey.f12);
    });

    test('parses all four modifiers combined', () {
      final result = parseKeyCombo('ctrl+alt+shift+meta+enter');
      expect(result.trigger, LogicalKeyboardKey.enter);
      expect(result.control, true);
      expect(result.alt, true);
      expect(result.shift, true);
      expect(result.meta, true);
    });

    test('handles special key names', () {
      expect(parseKeyCombo('escape').trigger, LogicalKeyboardKey.escape);
      expect(parseKeyCombo('backspace').trigger, LogicalKeyboardKey.backspace);
      expect(parseKeyCombo('enter').trigger, LogicalKeyboardKey.enter);
    });
  });

  group('buildComboString', () {
    test('builds simple key', () {
      expect(
        buildComboString(key: LogicalKeyboardKey.keyA),
        'a',
      );
    });

    test('builds with modifiers', () {
      expect(
        buildComboString(key: LogicalKeyboardKey.keyC, control: true),
        'ctrl+c',
      );
    });

    test('builds with multiple modifiers', () {
      expect(
        buildComboString(
          key: LogicalKeyboardKey.delete,
          control: true,
          alt: true,
        ),
        'ctrl+alt+delete',
      );
    });

    test('handles unknown key', () {
      expect(
        buildComboString(key: LogicalKeyboardKey.print),
        'unknown',
      );
    });

    test('roundtrip parse -> build', () {
      final original = 'ctrl+alt+shift+f5';
      final parsed = parseKeyCombo(original);
      final rebuilt = buildComboString(
        key: parsed.trigger,
        control: parsed.control,
        alt: parsed.alt,
        shift: parsed.shift,
        meta: parsed.meta,
      );
      expect(rebuilt, original);
    });
  });

  group('displayCombo', () {
    test('displays modifier names capitalized', () {
      expect(displayCombo('ctrl+c'), 'Ctrl+C');
      expect(displayCombo('alt+shift+x'), 'Alt+Shift+X');
    });

    test('displays arrow keys as unicode', () {
      expect(displayCombo('ctrl+arrowUp'), 'Ctrl+↑');
      expect(displayCombo('arrowDown'), '↓');
    });

    test('displays special key names', () {
      expect(displayCombo('delete'), 'Del');
      expect(displayCombo('space'), 'Space');
      expect(displayCombo('escape'), 'Esc');
      expect(displayCombo('enter'), 'Enter');
      expect(displayCombo('backspace'), 'Bksp');
    });

    test('displays single letter uppercase', () {
      expect(displayCombo('a'), 'A');
      expect(displayCombo('ctrl+z'), 'Ctrl+Z');
    });

    test('displays function keys', () {
      expect(displayCombo('f1'), 'F1');
      expect(displayCombo('f12'), 'F12');
    });
  });
}
