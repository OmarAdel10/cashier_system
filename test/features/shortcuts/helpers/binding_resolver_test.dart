import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/shortcuts/helpers/binding_resolver.dart';

void main() {
  group('findConflict', () {
    test('returns null when no conflict exists', () {
      final bindings = <String, String>{
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+i',
      };
      final result = findConflict(
        bindings: bindings,
        actionToken: 'nav.sales',
        keyCombo: 'ctrl+s',
      );
      expect(result, isNull);
    });

    test('returns conflicting action key when conflict found', () {
      final bindings = <String, String>{
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+i',
      };
      final result = findConflict(
        bindings: bindings,
        actionToken: 'nav.sales',
        keyCombo: 'ctrl+c',
      );
      expect(result, 'nav.checkout');
    });

    test('returns null when same action uses same key combo', () {
      final bindings = <String, String>{
        'nav.checkout': 'ctrl+c',
      };
      final result = findConflict(
        bindings: bindings,
        actionToken: 'nav.checkout',
        keyCombo: 'ctrl+c',
      );
      expect(result, isNull);
    });

    test('returns null with empty bindings', () {
      final result = findConflict(
        bindings: <String, String>{},
        actionToken: 'nav.checkout',
        keyCombo: 'ctrl+c',
      );
      expect(result, isNull);
    });

    test('finds first conflict among multiple', () {
      final bindings = <String, String>{
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+c',
      };
      final result = findConflict(
        bindings: bindings,
        actionToken: 'nav.sales',
        keyCombo: 'ctrl+c',
      );
      expect(result, 'nav.checkout');
    });
  });

  group('resolveBindingConflicts', () {
    test('adds binding when no conflict', () {
      final current = <String, String>{
        'nav.checkout': 'ctrl+c',
      };
      final result = resolveBindingConflicts(
        currentBindings: current,
        actionToken: 'nav.inventory',
        keyCombo: 'ctrl+i',
      );
      expect(result, {
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+i',
      });
    });

    test('removes conflicting binding', () {
      final current = <String, String>{
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+i',
      };
      final result = resolveBindingConflicts(
        currentBindings: current,
        actionToken: 'nav.inventory',
        keyCombo: 'ctrl+c',
      );
      expect(result, {
        'nav.inventory': 'ctrl+c',
      });
    });

    test('preserves other bindings when conflict removed', () {
      final current = <String, String>{
        'nav.checkout': 'ctrl+c',
        'nav.inventory': 'ctrl+i',
        'nav.sales': 'ctrl+s',
      };
      final result = resolveBindingConflicts(
        currentBindings: current,
        actionToken: 'nav.sales',
        keyCombo: 'ctrl+c',
      );
      expect(result, {
        'nav.inventory': 'ctrl+i',
        'nav.sales': 'ctrl+c',
      });
    });

    test('does not modify original map', () {
      final current = <String, String>{
        'nav.checkout': 'ctrl+c',
      };
      final result = resolveBindingConflicts(
        currentBindings: current,
        actionToken: 'nav.inventory',
        keyCombo: 'ctrl+c',
      );
      expect(current, {'nav.checkout': 'ctrl+c'});
      expect(result, {'nav.inventory': 'ctrl+c'});
    });

    test('works with empty current bindings', () {
      final result = resolveBindingConflicts(
        currentBindings: <String, String>{},
        actionToken: 'nav.checkout',
        keyCombo: 'ctrl+c',
      );
      expect(result, {'nav.checkout': 'ctrl+c'});
    });
  });
}
