import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import '../../helpers/fake_inventory_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
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

  group('initial state', () {
    test('should have initial status with empty inventory', () {
      expect(bloc.state.status, InventoryStatus.initial);
      expect(bloc.state.inventoryMap, isEmpty);
      expect(bloc.state.quickTileList, isEmpty);
      expect(bloc.state.searchResults, isEmpty);
      expect(bloc.state.searchQuery, '');
      expect(bloc.state.failure, isNull);
    });
  });

  group('LoadInventory', () {
    test('should load inventory and emit ready state', () async {
      bloc.add(const LoadInventory());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<InventoryState>((s) => s.status == InventoryStatus.loading),
          predicate<InventoryState>((s) => s.status == InventoryStatus.ready),
        ]),
      );
    });
  });

  group('AddProduct', () {
    test('should add product to inventory map', () async {
      bloc.add(const AddProduct(
        barcode: '123456789012',
        name: 'Test Product',
        price: 15.99,
        purchasePrice: 5.99,
        stock: 10,
        isQuickTile: true,
        tileColorHex: '#10B981',
      ));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>((s) =>
              s.status == InventoryStatus.ready &&
              s.inventoryMap.containsKey('123456789012') &&
              s.inventoryMap['123456789012']!.name == 'Test Product' &&
              s.inventoryMap['123456789012']!.purchasePrice == 5.99 &&
              s.quickTileList.length == 1),
        ),
      );
    });

    test('AddProduct preserves notes', () async {
      bloc.add(const AddProduct(
        barcode: 'x1',
        name: 'X',
        price: 10,
        purchasePrice: 5,
        stock: 3,
        isQuickTile: false,
        notes: 'shelf 2',
      ));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>((s) =>
              s.status == InventoryStatus.ready &&
              s.inventoryMap['x1']!.notes == 'shelf 2'),
        ),
      );
    });
  });

  group('SearchProducts', () {
    test('should filter products by name', () async {
      bloc.add(const AddProduct(barcode: '111', name: 'Apple'));
      await bloc.stream.first;

      bloc.add(const SearchProducts('Apple'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>((s) =>
              s.searchResults.length == 1 &&
              s.searchResults.first.name == 'Apple'),
        ),
      );
    });

    test('should clear search results on empty query', () async {
      bloc.add(const SearchProducts(''));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>((s) =>
              s.searchResults.isEmpty && s.searchQuery.isEmpty),
        ),
      );
    });
  });

  group('DeleteProduct', () {
    test('should remove product from inventory map', () async {
      bloc.add(const AddProduct(barcode: '111', name: 'To Delete'));
      await bloc.stream.first;

      bloc.add(const DeleteProduct('111'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>((s) =>
              s.status == InventoryStatus.ready &&
              !s.inventoryMap.containsKey('111')),
        ),
      );
    });
  });

  group('serialization', () {
    test('should persist and restore state via HydratedBloc', () async {
      bloc.add(const AddProduct(barcode: '123', name: 'Test'));
      await bloc.stream.first;

      final stored = await HydratedBloc.storage.read('InventoryBloc');
      expect(stored, isNotNull);
      expect((stored as Map)['inventory'], isA<List>());
    });

    test('should serialize and deserialize correctly via fromJson/toJson', () async {
      bloc.add(const AddProduct(
        barcode: '123',
        name: 'Saved',
        price: 20.0,
        purchasePrice: 8.25,
      ));
      await bloc.stream.first;
      expect(bloc.state.status, InventoryStatus.ready);

      final json = bloc.toJson(bloc.state);
      expect(json, isNotNull);
      final data = json!;
      expect(data['inventory'], isA<List>());
      expect((data['inventory'] as List).length, 1);
      expect((data['inventory'] as List).first['name'], 'Saved');
      expect((data['inventory'] as List).first['purchasePrice'], 8.25);

      final restored = bloc.fromJson(data);
      expect(restored, isNotNull);
      expect(restored!.status, InventoryStatus.ready);
      expect(restored.inventoryMap.containsKey('123'), isTrue);
      expect(restored.inventoryMap['123']!.name, 'Saved');
      expect(restored.inventoryMap['123']!.purchasePrice, 8.25);
    });

    test('fromJson should handle empty list', () {
      final restored = bloc.fromJson({'inventory': <dynamic>[]});
      expect(restored, isNotNull);
      expect(restored!.inventoryMap, isEmpty);
    });
  });
}
