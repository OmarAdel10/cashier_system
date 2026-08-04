import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/widgets/animated_counter.dart';
import 'package:cashier_system/features/checkout/domain/entities/cart_item_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/cart_table_widget.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/settings/helpers/fake_settings_repository.dart';

// ---------------------------------------------------------------------------
// Mock HydratedBloc storage
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------
Widget _buildTestWidget({
  required CheckoutBloc checkoutBloc,
  required SettingsBloc settingsBloc,
  required List<CartItemEntity> items,
  void Function(String, int)? onQuantityChanged,
}) {
  return MaterialApp(
    home: BlocProvider<CheckoutBloc>.value(
      value: checkoutBloc,
      child: BlocProvider<SettingsBloc>.value(
        value: settingsBloc,
        child: Scaffold(
          body: CartTableWidget(
            items: items,
            onQuantityChanged: onQuantityChanged ?? (_, __) {},
          ),
        ),
      ),
    ),
  );
}

List<CartItemEntity> _sampleItems() => [
      CartItemEntity(
        barcode: '111',
        name: 'Pen',
        quantity: 2,
        unitPricePiastres: 1500,
      ),
      CartItemEntity(
        barcode: '222',
        name: 'Notebook',
        quantity: 1,
        unitPricePiastres: 2500,
      ),
    ];

void main() {
  late CheckoutBloc checkoutBloc;
  late SettingsBloc settingsBloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    checkoutBloc = CheckoutBloc();
    settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    addTearDown(() {
      checkoutBloc.close();
      settingsBloc.close();
    });
  });

  group('CartTableWidget', () {
    testWidgets('renders without crashing when empty', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: [],
        ),
      );
      await tester.pump();

      expect(find.byType(CartTableWidget), findsOneWidget);
      // Table headers should be present (localized text)
      expect(find.byType(Table), findsWidgets);
    });

    testWidgets('renders items in table', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      expect(find.text('Pen'), findsOneWidget);
      expect(find.text('Notebook'), findsOneWidget);
    });

    testWidgets('renders row numbers', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      // Row 1 and Row 2 as strings appear in the table
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('footer shows total row', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      // Footer table row with AnimatedCounter for quantity and total
      expect(find.byType(AnimatedCounter), findsWidgets);
    });

    testWidgets('calls onQuantityChanged callback when provided', (tester) async {
      String? capturedBarcode;
      int? capturedQty;

      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
          onQuantityChanged: (barcode, qty) {
            capturedBarcode = barcode;
            capturedQty = qty;
          },
        ),
      );
      await tester.pump();

      // Verify callback is wired through (not called yet)
      expect(capturedBarcode, isNull);
      expect(capturedQty, isNull);
    });

    testWidgets('handles single item', (tester) async {
      final singleItem = CartItemEntity(
        barcode: '111',
        name: 'Single',
        quantity: 1,
        unitPricePiastres: 1000,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: [singleItem],
        ),
      );
      await tester.pump();

      expect(find.text('Single'), findsOneWidget);
    });

    testWidgets('handles item with zero quantity', (tester) async {
      final zeroQtyItem = CartItemEntity(
        barcode: '000',
        name: 'Zero Item',
        quantity: 0,
        unitPricePiastres: 500,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: [zeroQtyItem],
        ),
      );
      await tester.pump();

      expect(find.text('Zero Item'), findsOneWidget);
    });
  });

  group('CartTableWidget keyboard shortcuts', () {
    testWidgets('enter starts editing the selected row', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      // Tap first row to focus the table
      await tester.tap(find.text('Pen'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('typed quantity commits when editing finishes',
        (tester) async {
      String? capturedBarcode;
      int? capturedQty;

      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
          onQuantityChanged: (barcode, qty) {
            capturedBarcode = barcode;
            capturedQty = qty;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pen'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();

      // Tap another row to end editing (focus loss commits)
      await tester.tap(find.text('Notebook'));
      await tester.pump();

      expect(capturedBarcode, '111');
      expect(capturedQty, 5);
    });

    testWidgets('arrow down then delete removes the next item',
        (tester) async {
      final received = <CheckoutEvent>[];
      checkoutBloc = _TrackingCheckoutBloc(received);
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pen'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        received.whereType<RemoveFromCart>().any((e) => e.barcode == '222'),
        isTrue,
      );
    });

    testWidgets('selection wraps around the list', (tester) async {
      final received = <CheckoutEvent>[];
      checkoutBloc = _TrackingCheckoutBloc(received);
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pen'));
      await tester.pump();

      // Down twice wraps from 0 -> 1 -> 0
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        received.whereType<RemoveFromCart>().any((e) => e.barcode == '111'),
        isTrue,
      );
    });

    testWidgets('removing item while editing last row does not crash',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: _sampleItems(),
        ),
      );
      await tester.pump();

      // Select and start editing the second row
      await tester.tap(find.text('Notebook'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      // Items shrink (e.g. scanner removes a line) while editing
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: [
            _sampleItems().first,
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // No crash; editing reset
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete with empty cart does not crash', (tester) async {
      final received = <CheckoutEvent>[];
      checkoutBloc = _TrackingCheckoutBloc(received);
      await tester.pumpWidget(
        _buildTestWidget(
          checkoutBloc: checkoutBloc,
          settingsBloc: settingsBloc,
          items: [],
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(received.whereType<RemoveFromCart>(), isEmpty);
    });
  });
}

class _TrackingCheckoutBloc extends CheckoutBloc {
  final List<CheckoutEvent> received;
  _TrackingCheckoutBloc(this.received);

  @override
  void onEvent(CheckoutEvent event) {
    received.add(event);
    super.onEvent(event);
  }
}
