import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_state.dart';
import '../../helpers/fake_inventory_repository.dart';

void main() {
  late InventoryBloc bloc;
  late FakeInventoryRepository repository;

  setUp(() {
    repository = FakeInventoryRepository();
    bloc = InventoryBloc(repository: repository);
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
      bloc.add(
        const AddProduct(
          barcode: '123456789012',
          name: 'Test Product',
          price: 15.99,
          purchasePrice: 5.99,
          stock: 10,
          isQuickTile: true,
          tileColorHex: '#10B981',
        ),
      );

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>(
            (s) =>
                s.status == InventoryStatus.ready &&
                s.inventoryMap.containsKey('123456789012') &&
                s.inventoryMap['123456789012']!.name == 'Test Product' &&
                s.inventoryMap['123456789012']!.purchasePrice == 5.99 &&
                s.quickTileList.length == 1,
          ),
        ),
      );
    });

    test('AddProduct preserves notes', () async {
      bloc.add(
        const AddProduct(
          barcode: 'x1',
          name: 'X',
          price: 10,
          purchasePrice: 5,
          stock: 3,
          isQuickTile: false,
          notes: 'shelf 2',
        ),
      );

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>(
            (s) =>
                s.status == InventoryStatus.ready &&
                s.inventoryMap['x1']!.notes == 'shelf 2',
          ),
        ),
      );
    });

    test('AddProduct carries category', () async {
      bloc.add(
        const AddProduct(
          barcode: 'x2',
          name: 'Y',
          price: 10,
          purchasePrice: 5,
          stock: 3,
          isQuickTile: false,
          category: 'hot drinks',
        ),
      );

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>(
            (s) =>
                s.status == InventoryStatus.ready &&
                s.inventoryMap['x2']!.category == 'hot drinks',
          ),
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
          predicate<InventoryState>(
            (s) =>
                s.searchResults.length == 1 &&
                s.searchResults.first.name == 'Apple',
          ),
        ),
      );
    });

    test('should clear search results on empty query', () async {
      bloc.add(const SearchProducts(''));

      await expectLater(
        bloc.stream,
        emits(
          predicate<InventoryState>(
            (s) => s.searchResults.isEmpty && s.searchQuery.isEmpty,
          ),
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
          predicate<InventoryState>(
            (s) =>
                s.status == InventoryStatus.ready &&
                !s.inventoryMap.containsKey('111'),
          ),
        ),
      );
    });
  });

  group('persistence', () {
    test(
      'should persist product to repository and restore via LoadInventory',
      () async {
        bloc.add(
          const AddProduct(
            barcode: '123',
            name: 'Saved',
            price: 20.0,
            purchasePrice: 8.25,
            notes: 'keep me',
          ),
        );
        await bloc.stream.first;
        expect(bloc.state.status, InventoryStatus.ready);
        expect(bloc.state.inventoryMap.containsKey('123'), isTrue);

        bloc.add(const LoadInventory());
        await bloc.stream.first;
        await bloc.stream.first;

        expect(bloc.state.inventoryMap.containsKey('123'), isTrue);
        expect(bloc.state.inventoryMap['123']!.name, 'Saved');
        expect(bloc.state.inventoryMap['123']!.purchasePrice, 8.25);
        expect(bloc.state.inventoryMap['123']!.notes, 'keep me');
      },
    );
  });
}
