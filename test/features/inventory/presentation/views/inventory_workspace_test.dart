import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/inventory/presentation/views/inventory_workspace.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../helpers/fake_inventory_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async { _store[key] = value; }
  @override
  Future<dynamic> read(String key) async => _store[key];
  @override
  Future<void> delete(String key) async { _store.remove(key); }
  @override
  Future<void> clear() async { _store.clear(); }
  @override
  Future<void> close() async {}
}

Widget _buildTestWidget(InventoryBloc bloc) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<InventoryBloc>.value(value: bloc),
        BlocProvider<SettingsBloc>(
          create: (_) {
            final sBloc = SettingsBloc(repository: FakeSettingsRepository());
            sBloc.add(const LoadSettings());
            return sBloc;
          },
        ),
      ],
      child: const InventoryWorkspace(),
    ),
  );
}

void main() {
  late InventoryBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = InventoryBloc(repository: FakeInventoryRepository());
  });

  tearDown(() {
    bloc.close();
  });

  group('InventoryWorkspace', () {
    testWidgets('should show loading indicator initially', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show empty state when no products', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      bloc.add(const LoadInventory());
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      expect(find.text('لا توجد منتجات بعد'), findsOneWidget);
      expect(find.text('اضغط + لإضافة أول منتج'), findsOneWidget);
    });

    testWidgets('should show product card after adding product', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      bloc.add(const LoadInventory());
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      bloc.add(const AddProduct(barcode: '123456789012', name: 'Test Product', price: 9.99, stock: 5));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.textContaining('123456789012'), findsOneWidget);
      expect(find.textContaining('9.99'), findsOneWidget);
      expect(find.textContaining('المخزون: 5'), findsOneWidget);
    });

    testWidgets('should show AppBar with title and add button', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('المخزون'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.plus), findsOneWidget);
    });
  });
}
