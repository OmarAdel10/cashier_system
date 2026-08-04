import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/shortcuts/default_bindings.dart';
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

    test('parses plain function key', () {
      final activator = parseKeyCombo('f12');
      expect(activator.trigger, LogicalKeyboardKey.f12);
      expect(activator.control, isFalse);
      expect(activator.alt, isFalse);
      expect(activator.shift, isFalse);
      expect(activator.meta, isFalse);
    });

    test('parses ctrl modifier', () {
      final activator = parseKeyCombo('ctrl+f');
      expect(activator.trigger, LogicalKeyboardKey.keyF);
      expect(activator.control, isTrue);
    });

    test('parses alt modifier', () {
      final activator = parseKeyCombo('alt+1');
      expect(activator.trigger, LogicalKeyboardKey.digit1);
      expect(activator.alt, isTrue);
    });

    test('parses shift modifier', () {
      final activator = parseKeyCombo('shift+arrowUp');
      expect(activator.trigger, LogicalKeyboardKey.arrowUp);
      expect(activator.shift, isTrue);
    });

    test('parses meta modifier', () {
      final activator = parseKeyCombo('meta+p');
      expect(activator.trigger, LogicalKeyboardKey.keyP);
      expect(activator.meta, isTrue);
    });

    test('is case-insensitive', () {
      final activator = parseKeyCombo('CTRL+F');
      expect(activator.trigger, LogicalKeyboardKey.keyF);
      expect(activator.control, isTrue);
    });

    test('falls back to help key for unknown tokens', () {
      final activator = parseKeyCombo('tab');
      expect(activator.trigger, LogicalKeyboardKey.help);
    });

    test('includeRepeats defaults to true', () {
      expect(parseKeyCombo('f5').includeRepeats, isTrue);
    });

    test('includeRepeats can be disabled', () {
      expect(
        parseKeyCombo('f5', includeRepeats: false).includeRepeats,
        isFalse,
      );
    });
  });

  group('buildComboString', () {
    test('builds simple key', () {
      expect(buildComboString(key: LogicalKeyboardKey.keyA), 'a');
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
      expect(buildComboString(key: LogicalKeyboardKey.print), 'unknown');
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

    test('builds plain combo', () {
      expect(buildComboString(key: LogicalKeyboardKey.f12), 'f12');
    });

    test('builds modifier combo in canonical order', () {
      expect(
        buildComboString(
          key: LogicalKeyboardKey.keyF,
          control: true,
          alt: true,
          shift: true,
          meta: true,
        ),
        'ctrl+alt+shift+meta+f',
      );
    });

    test('returns unknown for unmapped key', () {
      expect(buildComboString(key: LogicalKeyboardKey.tab), 'unknown');
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

    test('formats modifiers', () {
      expect(displayCombo('ctrl+f'), 'Ctrl+F');
    });

    test('formats arrows', () {
      expect(displayCombo('arrowDown'), '\u2193');
      expect(displayCombo('arrowUp'), '\u2191');
      expect(displayCombo('arrowLeft'), '\u2190');
      expect(displayCombo('arrowRight'), '\u2192');
    });

    test('formats special keys', () {
      expect(displayCombo('space'), 'Space');
      expect(displayCombo('delete'), 'Del');
      expect(displayCombo('escape'), 'Esc');
      expect(displayCombo('enter'), 'Enter');
      expect(displayCombo('backspace'), 'Bksp');
    });

    test('formats function keys', () {
      expect(displayCombo('f12'), 'F12');
    });
  });

  group('isSupportedKey', () {
    test('accepts mapped keys', () {
      expect(isSupportedKey(LogicalKeyboardKey.f5), isTrue);
      expect(isSupportedKey(LogicalKeyboardKey.keyA), isTrue);
      expect(isSupportedKey(LogicalKeyboardKey.arrowUp), isTrue);
      expect(isSupportedKey(LogicalKeyboardKey.slash), isTrue);
    });

    test('rejects unmapped keys', () {
      expect(isSupportedKey(LogicalKeyboardKey.tab), isFalse);
      expect(isSupportedKey(LogicalKeyboardKey.numpad0), isFalse);
      expect(isSupportedKey(LogicalKeyboardKey.home), isFalse);
      expect(isSupportedKey(LogicalKeyboardKey.help), isFalse);
    });
  });

  group('isBareSafeKey', () {
    test('accepts function keys', () {
      expect(isBareSafeKey(LogicalKeyboardKey.f1), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.f12), isTrue);
    });

    test('accepts arrow keys', () {
      expect(isBareSafeKey(LogicalKeyboardKey.arrowUp), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.arrowDown), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.arrowLeft), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.arrowRight), isTrue);
    });

    test('accepts navigation/safe keys', () {
      expect(isBareSafeKey(LogicalKeyboardKey.escape), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.delete), isTrue);
      expect(isBareSafeKey(LogicalKeyboardKey.backspace), isTrue);
    });

    test('rejects printable keys (digits, letters)', () {
      expect(isBareSafeKey(LogicalKeyboardKey.digit1), isFalse);
      expect(isBareSafeKey(LogicalKeyboardKey.keyA), isFalse);
      expect(isBareSafeKey(LogicalKeyboardKey.slash), isFalse);
    });

    test('rejects space and enter', () {
      expect(isBareSafeKey(LogicalKeyboardKey.space), isFalse);
      expect(isBareSafeKey(LogicalKeyboardKey.enter), isFalse);
    });
  });

  group('round-trip', () {
    test('every default binding survives parse->build', () {
      for (final entry in defaultBindings.entries) {
        for (final combo in entry.value) {
          final activator = parseKeyCombo(combo);
          final rebuilt = buildComboString(
            key: activator.trigger,
            control: activator.control,
            alt: activator.alt,
            shift: activator.shift,
            meta: activator.meta,
          );
          expect(
            rebuilt,
            combo,
            reason: 'combo $combo for ${entry.key} did not round-trip',
          );
        }
      }
    });
  });
}
