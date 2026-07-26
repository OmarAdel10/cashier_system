import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../data/models/app_product_model.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/i_inventory_repository.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

class InventoryBloc extends HydratedBloc<InventoryEvent, InventoryState> {
  final IInventoryRepository _repository;

  InventoryBloc({required IInventoryRepository repository})
      : _repository = repository, super(const InventoryState()) {
    on<LoadInventory>(_onLoadInventory);
    on<AddProduct>(_onAddProduct);
    on<ToggleQuickTile>(_onToggleQuickTile);
    on<UpdateTileColor>(_onUpdateTileColor);
    on<SearchProducts>(_onSearchProducts);
    on<DeleteProduct>(_onDeleteProduct);
    on<LookupProduct>(_onLookupProduct);
    on<RefreshInventory>(_onRefreshInventory);
  }

  Future<void> _onLoadInventory(LoadInventory event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearFailure: true));
    final result = await _repository.getInventory();
    await result.fold(
      (failure) async => emit(state.copyWith(status: InventoryStatus.error, failure: failure)),
      (inventory) async {
        final tiles = await _repository.getQuickTiles();
        tiles.fold(
          (_) => emit(state.copyWith(
            status: InventoryStatus.ready,
            inventoryMap: inventory,
            quickTileList: const [],
            clearFailure: true,
          )),
          (t) => emit(state.copyWith(
            status: InventoryStatus.ready,
            inventoryMap: inventory,
            quickTileList: t,
            clearFailure: true,
          )),
        );
      },
    );
  }

  Future<void> _onAddProduct(AddProduct event, Emitter<InventoryState> emit) async {
    final product = ProductEntity(
      barcode: event.barcode,
      name: event.name,
      price: event.price,
      stock: event.stock,
      isQuickTile: event.isQuickTile,
      tileColorHex: event.tileColorHex,
    );
    final result = await _repository.saveProduct(product);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) {
        final map = Map<String, ProductEntity>.from(state.inventoryMap)
          ..[product.barcode] = product;
        emit(state.copyWith(
          status: InventoryStatus.ready,
          inventoryMap: map,
          quickTileList: map.values.where((p) => p.isQuickTile).toList(),
          clearFailure: true,
        ));
      },
    );
  }

  Future<void> _onToggleQuickTile(ToggleQuickTile event, Emitter<InventoryState> emit) async {
    (await _repository.toggleQuickTile(event.barcode)).fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) => add(const LoadInventory()),
    );
  }

  Future<void> _onUpdateTileColor(UpdateTileColor event, Emitter<InventoryState> emit) async {
    (await _repository.updateTileColor(event.barcode, event.colorHex)).fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) => add(const LoadInventory()),
    );
  }

  Future<void> _onSearchProducts(SearchProducts event, Emitter<InventoryState> emit) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(searchResults: [], searchQuery: ''));
      return;
    }
    final q = event.query.toLowerCase();
    emit(state.copyWith(
      searchResults: state.inventoryMap.values
          .where((p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q))
          .toList(),
      searchQuery: event.query,
    ));
  }

  Future<void> _onDeleteProduct(DeleteProduct event, Emitter<InventoryState> emit) async {
    final result = await _repository.deleteProduct(event.barcode);
    result.fold(
      (f) => emit(state.copyWith(status: InventoryStatus.error, failure: f)),
      (_) {
        final map = Map<String, ProductEntity>.from(state.inventoryMap)
          ..remove(event.barcode);
        emit(state.copyWith(
          status: InventoryStatus.ready,
          inventoryMap: map,
          quickTileList: map.values.where((p) => p.isQuickTile).toList(),
          clearFailure: true,
        ));
      },
    );
  }

  void _onLookupProduct(LookupProduct event, Emitter<InventoryState> emit) {
    final product = state.inventoryMap[event.barcode];
    emit(state.copyWith(
      lookupResult: product,
      clearFailure: true,
    ));
  }

  Future<void> _onRefreshInventory(RefreshInventory event, Emitter<InventoryState> emit) async {
    final result = await _repository.getInventory();
    await result.fold(
      (_) async {},
      (inventory) async {
        final tiles = await _repository.getQuickTiles();
        await tiles.fold(
          (_) async => emit(state.copyWith(
            inventoryMap: inventory,
            quickTileList: const [],
          )),
          (t) async => emit(state.copyWith(
            inventoryMap: inventory,
            quickTileList: t,
          )),
        );
      },
    );
  }

  @override
  InventoryState? fromJson(Map<String, dynamic> json) {
    try {
      final products = (json['inventory'] as List<dynamic>?)?.map((e) {
        return AppProductModel.fromJson(e as Map<String, dynamic>).toEntity();
      }).toList() ?? [];

      final map = <String, ProductEntity>{};
      for (final p in products) {
        map[p.barcode] = p;
      }
      return InventoryState(
        status: InventoryStatus.ready,
        inventoryMap: map,
        quickTileList: products.where((p) => p.isQuickTile).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(InventoryState state) {
    if (state.status != InventoryStatus.ready) return null;
    try {
      final list = state.inventoryMap.values.map((p) {
        return AppProductModel(
          barcode: p.barcode,
          name: p.name,
          price: p.price,
          stock: p.stock,
          isQuickTile: p.isQuickTile,
          tileColorHex: p.tileColorHex,
        ).toJson();
      }).toList();
      return {'inventory': list};
    } catch (_) {
      return null;
    }
  }
}
