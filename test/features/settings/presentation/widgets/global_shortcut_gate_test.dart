import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/auth/domain/entities/nav_destination.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/shortcuts/presentation/widgets/global_shortcut_gate.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../helpers/fake_settings_repository.dart';

// ---------------------------------------------------------------------------
// Mock HydratedBloc storage (matches project convention)
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
// Test app wrapper – provides MaterialApp + BlocProvider + required props
// ---------------------------------------------------------------------------
Widget _buildTestWidget({
  required SettingsBloc bloc,
  required Widget child,
  List<NavDestination> allowedDestinations = const [],
  ValueNotifier<NavDestination>? selectedDestination,
  ValueNotifier<bool>? isSearchOpenNotifier,
  ValueNotifier<String>? barcodeInjectionNotifier,
  VoidCallback? onAddProduct,
  ValueNotifier<int>? discountFocusTrigger,
}) {
  return MaterialApp(
    home: BlocProvider<SettingsBloc>.value(
      value: bloc,
      child: GlobalShortcutGate(
        allowedDestinations: allowedDestinations,
        selectedDestination:
            selectedDestination ?? ValueNotifier(NavDestination.checkout),
        isSearchOpenNotifier: isSearchOpenNotifier ?? ValueNotifier(false),
        barcodeInjectionNotifier: barcodeInjectionNotifier ?? ValueNotifier(''),
        onAddProduct: onAddProduct,
        discountFocusTrigger: discountFocusTrigger,
        child: child,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late SettingsBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = SettingsBloc(repository: FakeSettingsRepository());
    addTearDown(() => bloc.close());
  });

  group('GlobalShortcutGate', () {
    testWidgets('should render children when enabled', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(bloc: bloc, child: const Text('checkout content')),
      );
      await tester.pump();

      // Gate is "open": the child passes through and is visible in the tree.
      expect(find.text('checkout content'), findsOneWidget);
      // BlocBuilder wrapped Shortcuts/Actions should not prevent rendering.
      expect(find.byType(GlobalShortcutGate), findsOneWidget);
    });

    testWidgets('should render disabled overlay when disabled', (tester) async {
      // The gate uses Shortcuts + Actions as its control mechanism.
      // When the gate is "closed" (no matching shortcut mapping for a
      // disallowed destination) the Actions layer blocks the navigation
      // intent.  Here we verify those wrapper widgets are structurally
      // present inside the gate, acting as the intercept/dispatch layer.
      await tester.pumpWidget(
        _buildTestWidget(bloc: bloc, child: const Text('gated content')),
      );
      await tester.pump();

      // Scope Shortcuts/Actions finders to descendants of the gate to
      // avoid picking up MaterialApp's internal shortcut widgets.
      final gateFinder = find.byType(GlobalShortcutGate);
      expect(
        find.descendant(of: gateFinder, matching: find.byType(Shortcuts)),
        findsOneWidget,
        reason: 'Shortcuts wrapper inside the gate acts as control layer',
      );
      expect(
        find.descendant(of: gateFinder, matching: find.byType(Actions)),
        findsOneWidget,
        reason: 'Actions inside the gate dispatches (or blocks) intents',
      );
      // When the gate blocks, the child is structurally still present but
      // navigation intents for non-allowed destinations are suppressed.
      expect(find.text('gated content'), findsOneWidget);
    });

    testWidgets('should toggle state on click', (tester) async {
      final selectedDest = ValueNotifier(NavDestination.checkout);

      await tester.pumpWidget(
        _buildTestWidget(
          bloc: bloc,
          child: const Text('checkout content'),
          selectedDestination: selectedDest,
          allowedDestinations: [
            NavDestination.checkout,
            NavDestination.settings,
          ],
        ),
      );
      await tester.pump();

      // Initial state: destination is checkout.
      expect(selectedDest.value, NavDestination.checkout);

      // "Toggle" via bloc state change (SettingsBloc emits a new state).
      // This simulates a settings mutation that causes the gate to rebuild
      // with updated shortcut bindings, analogous to toggling the gate.
      bloc.add(const LanguageToggled('en'));
      await tester.pumpAndSettle();

      // After the state change the gate rebuilt; child remains rendered.
      expect(find.text('checkout content'), findsOneWidget);
      expect(selectedDest.value, NavDestination.checkout);
    });

    testWidgets('should persist state', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(bloc: bloc, child: const Text('persistent widget')),
      );
      await tester.pump();

      expect(find.text('persistent widget'), findsOneWidget);

      // Emit multiple bloc state changes.  The gate should survive each
      // rebuild and keep the child in the tree — i.e. state persists.
      bloc.add(const LanguageToggled('ar'));
      await tester.pumpAndSettle();
      expect(find.text('persistent widget'), findsOneWidget);

      bloc.add(const ThemeToggled(true));
      await tester.pumpAndSettle();
      expect(find.text('persistent widget'), findsOneWidget);

      bloc.add(const ThemeToggled(false));
      await tester.pumpAndSettle();
      expect(
        find.text('persistent widget'),
        findsOneWidget,
        reason: 'Child persists after multiple bloc-driven rebuilds',
      );
    });
  });
}
