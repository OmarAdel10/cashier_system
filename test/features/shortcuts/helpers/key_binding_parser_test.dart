import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/shortcuts/default_bindings.dart';
import 'package:cashier_system/features/shortcuts/helpers/key_binding_parser.dart';

void main() {
  group('parseKeyCombo', () {
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
      expect(
        buildComboString(key: LogicalKeyboardKey.tab),
        'unknown',
      );
    });
  });

  group('displayCombo', () {
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
          expect(rebuilt, combo,
              reason: 'combo $combo for ${entry.key} did not round-trip');
        }
      }
    });
  });
}
