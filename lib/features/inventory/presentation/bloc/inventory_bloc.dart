import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/i_inventory_repository.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final IInventoryRepository _repository;

  InventoryBloc({required IInventoryRepository repository})
    : _repository = repository,
      super(const InventoryState()) {
    on<LoadInventory>(_onLoadInventory);
    on<AddProduct>(_onAddProduct);
    on<EditProduct>(_onEditProduct);
    on<ToggleQuickTile>(_onToggleQuickTile);
    on<UpdateTileColor>(_onUpdateTileColor);
    on<SearchProducts>(_onSearchProducts);
    on<DeleteProduct>(_onDeleteProduct);
    on<LookupProduct>(_onLookupProduct);
    on<RefreshInventory>(_onRefreshInventory);
    on<ImportProducts>(_onImportProducts);
  }

  Future<void> _onLoadInventory(
    LoadInventory event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearFailure: true));
    final result = await _repository.getInventory();
    await result.fold(
      (failure) async =>
          emit(state.copyWith(status: InventoryStatus.error, failure: failure)),
      (inventory) async {
        final tiles = await _repository.getQuickTiles();
        tiles.fold(
          (_) => emit(
            state.copyWith(
              status: InventoryStatus.ready,
              inventoryMap: inventory,
              quickTileList: const [],
              clearFailure: true,
            ),
          ),
          (t) => emit(
            state.copyWith(
              status: InventoryStatus.ready,
              inventoryMap: inventory,
              quickTileList: t,
              clearFailure: true,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<InventoryState> emit,
  ) async {
    final product = ProductEntity(
      barcode: event.barcode,
      name: event.name,
      price: event.price,
      stock: event.stock,
      isQuickTile: event.isQuickTile,
      tileColorHex: event.tileColorHex,
      notes: event.notes,
      category: event.category,
      prepCategory: event.prepCategory,
    );
    final result = await _repository.saveProduct(product);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) {
        final map = Map<String, ProductEntity>.from(state.inventoryMap)
          ..[product.barcode] = product;
        emit(
          state.copyWith(
            status: InventoryStatus.ready,
            inventoryMap: map,
            quickTileList: map.values.where((p) => p.isQuickTile).toList(),
            clearFailure: true,
          ),
        );
      },
    );
  }

  Future<void> _onEditProduct(
    EditProduct event,
    Emitter<InventoryState> emit,
  ) async {
    final product = ProductEntity(
      barcode: event.barcode,
      name: event.name,
      price: event.price,
      stock: event.stock,
      isQuickTile: event.isQuickTile,
      tileColorHex: event.tileColorHex,
      notes: event.notes,
      category: event.category,
      prepCategory: event.prepCategory,
    );
    final result = await _repository.updateProduct(event.oldBarcode, product);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) {
        final map = Map<String, ProductEntity>.from(state.inventoryMap)
          ..remove(event.oldBarcode)
          ..[event.barcode] = product;
        emit(
          state.copyWith(
            status: InventoryStatus.ready,
            inventoryMap: map,
            quickTileList: map.values.where((p) => p.isQuickTile).toList(),
            clearFailure: true,
          ),
        );
      },
    );
  }

  Future<void> _onToggleQuickTile(
    ToggleQuickTile event,
    Emitter<InventoryState> emit,
  ) async {
    (await _repository.toggleQuickTile(event.barcode)).fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) => add(const LoadInventory()),
    );
  }

  Future<void> _onUpdateTileColor(
    UpdateTileColor event,
    Emitter<InventoryState> emit,
  ) async {
    (await _repository.updateTileColor(event.barcode, event.colorHex)).fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) => add(const LoadInventory()),
    );
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<InventoryState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(searchResults: [], searchQuery: ''));
      return;
    }
    final q = event.query.toLowerCase();
    emit(
      state.copyWith(
        searchResults: state.inventoryMap.values
            .where(
              (p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q),
            )
            .toList(),
        searchQuery: event.query,
      ),
    );
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<InventoryState> emit,
  ) async {
    final result = await _repository.deleteProduct(event.barcode);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) {
        final map = Map<String, ProductEntity>.from(state.inventoryMap)
          ..remove(event.barcode);
        emit(
          state.copyWith(
            status: InventoryStatus.ready,
            inventoryMap: map,
            quickTileList: map.values.where((p) => p.isQuickTile).toList(),
            clearFailure: true,
          ),
        );
      },
    );
  }

  void _onLookupProduct(LookupProduct event, Emitter<InventoryState> emit) {
    final product = state.inventoryMap[event.barcode];
    emit(state.copyWith(lookupResult: product, clearFailure: true));
  }

  Future<void> _onRefreshInventory(
    RefreshInventory event,
    Emitter<InventoryState> emit,
  ) async {
    final result = await _repository.getInventory();
    await result.fold((_) async {}, (inventory) async {
      final tiles = await _repository.getQuickTiles();
      await tiles.fold(
        (_) async => emit(
          state.copyWith(inventoryMap: inventory, quickTileList: const []),
        ),
        (t) async =>
            emit(state.copyWith(inventoryMap: inventory, quickTileList: t)),
      );
    });
  }

  Future<void> _onImportProducts(
    ImportProducts event,
    Emitter<InventoryState> emit,
  ) async {
    var created = 0;
    var updated = 0;
    var failed = 0;

    for (final product in event.toCreate) {
      final result = await _repository.saveProduct(product);
      if (result.fold((_) => true, (_) => false)) {
        failed++;
      } else {
        created++;
      }
    }

    for (final product in event.toUpdate) {
      final result = await _repository.updateProduct(product.barcode, product);
      if (result.fold((_) => true, (_) => false)) {
        failed++;
      } else {
        updated++;
      }
    }

    if (created > 0 || updated > 0) {
      add(const LoadInventory());
    }

    emit(
      state.copyWith(
        importResult: ImportResult(
          created: created,
          updated: updated,
          failed: failed,
        ),
        clearFailure: true,
        clearImportResult: false,
      ),
    );
  }
}
