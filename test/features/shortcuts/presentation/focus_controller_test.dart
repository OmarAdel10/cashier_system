import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/auth/domain/entities/nav_destination.dart';
import 'package:cashier_system/features/shortcuts/presentation/focus_controller.dart';

void main() {
  group('FocusController — zone validity matrix', () {
    late FocusController controller;

    setUp(() {
      controller = FocusController();
    });
    tearDown(() {
      controller.dispose();
    });

    test('scanner zone valid only on checkout when scanner mode enabled', () {
      controller.attachScannerMode(true);
      controller.attachAllowedDestinations(const [
        NavDestination.checkout,
        NavDestination.sales,
        NavDestination.settings,
      ]);
      final d = _Dest(NavDestination.checkout);
      controller.attachDestination(d);

      expect(controller.canActivate(FocusZone.scanner), isTrue);
      d.value = NavDestination.sales;
      expect(controller.canActivate(FocusZone.scanner), isFalse);
      d.value = NavDestination.inventory;
      expect(controller.canActivate(FocusZone.scanner), isFalse);
      d.value = NavDestination.settings;
      expect(controller.canActivate(FocusZone.scanner), isFalse);
    });

    test('scanner zone invalid when scanner mode disabled', () {
      controller.attachScannerMode(false);
      controller.attachAllowedDestinations(const [NavDestination.checkout]);
      controller.attachDestination(_Dest(NavDestination.checkout));
      expect(controller.canActivate(FocusZone.scanner), isFalse);
    });

    test('cart zone valid only on checkout', () {
      controller.attachScannerMode(true);
      controller.attachAllowedDestinations(const [NavDestination.checkout]);
      final d = _Dest(NavDestination.checkout);
      controller.attachDestination(d);
      for (final dest in NavDestination.values) {
        d.value = dest;
        final expected = dest == NavDestination.checkout;
        expect(
          controller.canActivate(FocusZone.cart),
          expected,
          reason: 'cart on $dest should be $expected',
        );
      }
    });

    test('discount zone valid only on checkout', () {
      controller.attachScannerMode(true);
      controller.attachAllowedDestinations(const [NavDestination.checkout]);
      final d = _Dest(NavDestination.checkout);
      controller.attachDestination(d);
      for (final dest in NavDestination.values) {
        d.value = dest;
        expect(
          controller.canActivate(FocusZone.discount),
          dest == NavDestination.checkout,
          reason: 'discount on $dest',
        );
      }
    });

    test('grid zone valid only on checkout with scanner mode off', () {
      controller.attachAllowedDestinations(const [NavDestination.checkout]);
      final d = _Dest(NavDestination.checkout);
      controller.attachDestination(d);

      controller.attachScannerMode(true);
      expect(controller.canActivate(FocusZone.grid), isFalse);

      controller.attachScannerMode(false);
      expect(controller.canActivate(FocusZone.grid), isTrue);

      d.value = NavDestination.sales;
      expect(controller.canActivate(FocusZone.grid), isFalse);
    });
  });

  group('FocusController — destination change resets zone', () {
    test('leaving checkout clears non-scanner zones', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [
          NavDestination.checkout,
          NavDestination.sales,
          NavDestination.settings,
        ]);
      addTearDown(c.dispose);
      final d = _Dest(NavDestination.checkout);
      c.attachDestination(d);

      c.setZone(FocusZone.cart);
      expect(c.zone.value, FocusZone.cart);

      d.value = NavDestination.sales;
      expect(
        c.zone.value,
        isNot(FocusZone.cart),
        reason: 'cart zone should clear when leaving checkout',
      );
    });
  });

  group('FocusController — modal stack blocks canActivate', () {
    test('overlay push/pop updates overlayDepth', () {
      final c = FocusController();
      addTearDown(c.dispose);
      expect(c.modalStackDepth, 0);
      c.pushModal();
      expect(c.modalStackDepth, 1);
      c.popModal();
      expect(c.modalStackDepth, 0);
    });

    test('canActivate false while modal stack > 0', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [NavDestination.checkout])
        ..attachDestination(_Dest(NavDestination.checkout));
      addTearDown(c.dispose);

      c.pushModal();
      expect(c.canActivate(FocusZone.cart), isFalse);
      expect(c.canActivate(FocusZone.scanner), isFalse);

      c.popModal();
      expect(c.canActivate(FocusZone.cart), isTrue);
      expect(c.canActivate(FocusZone.scanner), isTrue);
    });

    test('NavigatorObserver route push/pop updates modalStackDepth', () {
      final c = FocusController();
      addTearDown(c.dispose);
      final r1 = _route();
      final r2 = _route();
      c.didPush(r1, null);
      c.didPush(r2, r1);
      expect(c.modalStackDepth, 2);
      c.didPop(r2, r1);
      expect(c.modalStackDepth, 1);
      c.didPop(r1, null);
      expect(c.modalStackDepth, 0);
    });

    test('canActivate blocked while any route open', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [NavDestination.checkout])
        ..attachDestination(_Dest(NavDestination.checkout));
      addTearDown(c.dispose);

      c.didPush(_route(), null);
      expect(c.canActivate(FocusZone.cart), isFalse);
      c.didPop(_route(), null);
      expect(c.canActivate(FocusZone.cart), isTrue);
    });
  });

  group('FocusController — effective nav defaults', () {
    test('cashier rail → f1/f2/f3', () {
      final c = FocusController()
        ..attachAllowedDestinations(const [
          NavDestination.checkout,
          NavDestination.sales,
          NavDestination.settings,
        ]);
      addTearDown(c.dispose);
      expect(c.effectiveNavDefaults[NavDestination.checkout], ['f1']);
      expect(c.effectiveNavDefaults[NavDestination.sales], ['f2']);
      expect(c.effectiveNavDefaults[NavDestination.settings], ['f3']);
      expect(c.effectiveNavDefaults[NavDestination.inventory], isNull);
    });

    test('admin rail → f1/f2/f3', () {
      final c = FocusController()
        ..attachAllowedDestinations(const [
          NavDestination.sales,
          NavDestination.inventory,
          NavDestination.settings,
        ]);
      addTearDown(c.dispose);
      expect(c.effectiveNavDefaults[NavDestination.sales], ['f1']);
      expect(c.effectiveNavDefaults[NavDestination.inventory], ['f2']);
      expect(c.effectiveNavDefaults[NavDestination.settings], ['f3']);
      expect(c.effectiveNavDefaults[NavDestination.checkout], isNull);
    });

    test('rail length < 3 has no F-key past rail length', () {
      final c = FocusController()
        ..attachAllowedDestinations(const [NavDestination.checkout]);
      addTearDown(c.dispose);
      expect(c.effectiveNavDefaults[NavDestination.checkout], ['f1']);
      expect(c.effectiveNavDefaults.containsKey(NavDestination.sales), isFalse);
    });
  });

  group('FocusController — canReclaimScanner predicate', () {
    test('false when no scanner node attached', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [NavDestination.checkout])
        ..attachDestination(_Dest(NavDestination.checkout));
      addTearDown(c.dispose);
      expect(c.canReclaimScanner(), isFalse);
    });

    test('true when all conditions met', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [NavDestination.checkout])
        ..attachDestination(_Dest(NavDestination.checkout));
      addTearDown(c.dispose);
      final node = FocusNode(debugLabel: 'scanner-test');
      addTearDown(node.dispose);
      c.attachScannerNode(node);
      expect(c.canReclaimScanner(), isTrue);
    });

    test('false when modal stack > 0', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [NavDestination.checkout])
        ..attachDestination(_Dest(NavDestination.checkout));
      addTearDown(c.dispose);
      final node = FocusNode(debugLabel: 'scanner-test');
      addTearDown(node.dispose);
      c.attachScannerNode(node);
      c.pushModal();
      expect(c.canReclaimScanner(), isFalse);
    });

    test('false when destination is not checkout', () {
      final c = FocusController()
        ..attachScannerMode(true)
        ..attachAllowedDestinations(const [
          NavDestination.checkout,
          NavDestination.sales,
        ])
        ..attachDestination(_Dest(NavDestination.sales));
      addTearDown(c.dispose);
      final node = FocusNode(debugLabel: 'scanner-test');
      addTearDown(node.dispose);
      c.attachScannerNode(node);
      expect(c.canReclaimScanner(), isFalse);
    });
  });
}

class _Dest extends ValueNotifier<NavDestination> {
  _Dest(super.value);
}

Route<dynamic> _route() {
  return MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink());
}
