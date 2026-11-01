import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:daftari/core/error/either.dart';
import 'package:daftari/core/error/failure.dart';
import 'package:daftari/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:daftari/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:daftari/features/checkout/presentation/widgets/barcode_scanner_gate.dart';
import 'package:daftari/features/inventory/domain/entities/product_entity.dart';
import 'package:daftari/features/inventory/domain/repositories/i_inventory_repository.dart';
import 'package:daftari/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:daftari/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:daftari/features/settings/presentation/bloc/settings_bloc.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};
  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;
  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async => _store.remove(key);
  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> close() async {}
}

class _TestInventoryBloc extends InventoryBloc {
  _TestInventoryBloc({List<ProductEntity> products = const []})
    : _products = products,
      super(repository: _FakeInventoryRepo());

  final List<ProductEntity> _products;

  @override
  InventoryState get state => InventoryState(
    inventoryMap: {for (final p in _products) p.barcode: p},
    quickTileList: const [],
    status: InventoryStatus.ready,
  );

  @override
  Stream<InventoryState> get stream => Stream.value(state);
}

class _FakeInventoryRepo implements IInventoryRepository {
  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async =>
      Right({});
  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateProduct(
    String oldBarcode,
    ProductEntity product,
  ) async => const Right(null);
  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async =>
      Right([]);
  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> updateTileColor(
    String barcode,
    String colorHex,
  ) async => const Right(null);
  @override
  Future<Either<Failure, void>> updateStock(
    String barcode,
    int deltaQuantity,
  ) async => const Right(null);
}

class _TrackingCheckoutBloc extends CheckoutBloc {
  final List<CheckoutEvent> receivedEvents = [];

  @override
  void onEvent(CheckoutEvent event) {
    receivedEvents.add(event);
    super.onEvent(event);
  }
}

Future<void> _scanBurst(WidgetTester tester, {String barcode = '111'}) async {
  for (final char in barcode.split('')) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: char);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
}

/// Dispatches a key-down with an explicit platform timestamp so the gate's
/// inter-character gap logic can be exercised deterministically. Synthesized
/// [KeyData] is dispatched immediately, exactly like the platform path.
// ignore: deprecated_member_use, deprecated_member_use
void _sendKeyDownAt(Duration timeStamp, String character) {
  ServicesBinding.instance.keyEventManager.handleKeyData(
    ui.KeyData(
      timeStamp: timeStamp,
      type: ui.KeyEventType.down,
      physical: PhysicalKeyboardKey.digit1.usbHidUsage,
      logical: LogicalKeyboardKey.digit1.keyId,
      character: character,
      synthesized: true,
    ),
  );
}

void main() {
  late SettingsBloc settingsBloc;
  late _TestInventoryBloc inventoryBloc;
  late _TrackingCheckoutBloc checkoutBloc;
  late ValueNotifier<bool> isSearchOpenNotifier;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    inventoryBloc = _TestInventoryBloc(
      products: [
        const ProductEntity(barcode: '1', name: 'Single', price: 1.0),
        const ProductEntity(barcode: '11', name: 'Tea', price: 3.0),
        const ProductEntity(barcode: '111', name: 'Water', price: 5.0),
      ],
    );
    checkoutBloc = _TrackingCheckoutBloc();
    isSearchOpenNotifier = ValueNotifier(false);
    addTearDown(() {
      settingsBloc.close();
      checkoutBloc.close();
      inventoryBloc.close();
      isSearchOpenNotifier.dispose();
    });
  });

  Widget buildGate({required Widget child}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<InventoryBloc>.value(value: inventoryBloc),
        BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
      ],
      child: MaterialApp(
        home: BarcodeScannerGate(
          isSearchOpenNotifier: isSearchOpenNotifier,
          child: child,
        ),
      ),
    );
  }

  testWidgets('scanner burst followed by enter adds product to cart once', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    await _scanBurst(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '111');
  });

  testWidgets('keystrokes separated by a long gap start a new barcode', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    // Two scans: '1' then '11'. The 500ms gap exceeds the 20ms
    // inter-character window, so the buffer must reset and the cart must
    // receive '11' rather than the merged '111'.
    _sendKeyDownAt(Duration.zero, '1');
    _sendKeyDownAt(const Duration(milliseconds: 500), '1');
    _sendKeyDownAt(const Duration(milliseconds: 510), '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '11');
  });

  testWidgets('enter is not consumed while a TextField is focused', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Column(children: [TextField()])),
      ),
    );
    await tester.pump();

    // Buffer fills with a scanner burst (scanner node focused)
    await _scanBurst(tester);

    // User focuses the TextField and presses enter
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // The raw handler must not swallow the Enter and fire a bogus scan
    // from the stale buffer (H1).
    expect(checkoutBloc.receivedEvents.whereType<AddToCart>(), isEmpty);
  });

  testWidgets('enter is not consumed while a dialog is open', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      buildGate(
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      content: FilledButton(
                        autofocus: true,
                        onPressed: () => pressed = true,
                        child: const Text('OK'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Buffer fills with a scanner burst (scanner node focused)
    await _scanBurst(tester);

    // Open dialog - focus moves to dialog route (outside scanner subtree)
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      pressed,
      isTrue,
      reason: 'raw handler must not swallow Enter from a dialog',
    );
    expect(checkoutBloc.receivedEvents.whereType<AddToCart>(), isEmpty);
  });

  testWidgets('disabled gate renders child without keyboard handling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<InventoryBloc>.value(value: inventoryBloc),
          BlocProvider<CheckoutBloc>.value(value: checkoutBloc),
        ],
        child: MaterialApp(
          home: BarcodeScannerGate(
            enabled: false,
            isSearchOpenNotifier: isSearchOpenNotifier,
            child: const Scaffold(body: Center(child: Text('grid-child'))),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('grid-child'), findsOneWidget);

    await _scanBurst(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(checkoutBloc.receivedEvents.whereType<AddToCart>(), isEmpty);
  });

  testWidgets('real-time stalls do not split a scanner burst', (tester) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    // Platform timestamps advance by 1ms each; real wall-clock burns 30ms
    // between deliveries. The gate uses platform timestamps, so the burst
    // must stay merged ('111') even though real time exceeded the 20ms gap.
    for (var i = 0; i < 3; i++) {
      _sendKeyDownAt(Duration(milliseconds: i), '1');
      // Burn real wall-clock time between deliveries.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '111');
  });

  testWidgets('inter-character gap at exactly 20ms appends, 21ms resets', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    // 20ms gap -> same burst -> '11'
    _sendKeyDownAt(Duration.zero, '1');
    _sendKeyDownAt(const Duration(milliseconds: 20), '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    var adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '11');

    // Reset for next test
    checkoutBloc.receivedEvents.clear();

    // 21ms gap -> reset -> two separate barcodes: first '1', then '1'
    // (the second '1' followed by Enter produces a single '1' in cart)
    _sendKeyDownAt(const Duration(milliseconds: 21), '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '1');
  });

  testWidgets('idle reset timer discards partial buffer after 200ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    _sendKeyDownAt(Duration.zero, '1');
    // Wait past the 200ms reset timeout
    await tester.pump(const Duration(milliseconds: 250));
    _sendKeyDownAt(const Duration(milliseconds: 300), '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '1');
  });

  testWidgets('non-character keys are ignored and do not flush buffer', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(
        child: const Scaffold(body: Center(child: Text('scanner-child'))),
      ),
    );
    await tester.pump();

    // Shift key (modifier, no character) followed by Enter should not
    // produce an empty AddToCart or swallow the Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      checkoutBloc.receivedEvents.whereType<AddToCart>(),
      isEmpty,
      reason: 'modifier key must not enter buffer or flush',
    );

    // Valid burst after modifier still works
    await _scanBurst(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final adds = checkoutBloc.receivedEvents.whereType<AddToCart>().toList();
    expect(adds.length, 1);
    expect(adds.single.barcode, '111');
  });
}
