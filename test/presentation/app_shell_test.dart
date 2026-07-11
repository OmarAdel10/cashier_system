import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/presentation/app_shell.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../features/inventory/helpers/fake_inventory_repository.dart';
import '../features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

Widget _buildTestApp() {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = SettingsBloc(repository: FakeSettingsRepository());
            bloc.add(const LoadSettings());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) {
            final bloc = InventoryBloc(repository: FakeInventoryRepository());
            bloc.add(const LoadInventory());
            return bloc;
          },
        ),
        BlocProvider(create: (_) => CheckoutBloc()),
      ],
      child: const AppShell(),
    ),
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  group('AppShell', () {
    testWidgets('renders 4 nav items in the rail', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIcons.shoppingCartSimple), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.package), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.chartBar), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.gearSix), findsOneWidget);
    });

    testWidgets('shows SettingsWorkspace when settings nav is tapped', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.gearSix));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders receipt tower panel on checkout view', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('الفاتورة'), findsAtLeastNWidgets(1));
    });
  });
}
