import '../../../../core/error/failure.dart';
import '../../domain/entities/product_entity.dart';

enum InventoryStatus { initial, loading, ready, error }

class InventoryState {
  final InventoryStatus status;
  final Map<String, ProductEntity> inventoryMap;
  final List<ProductEntity> quickTileList;
  final List<ProductEntity> searchResults;
  final String searchQuery;
  final Failure? failure;
  final ProductEntity? lookupResult;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.inventoryMap = const {},
    this.quickTileList = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.failure,
    this.lookupResult,
  });

  InventoryState copyWith({
    InventoryStatus? status,
    Map<String, ProductEntity>? inventoryMap,
    List<ProductEntity>? quickTileList,
    List<ProductEntity>? searchResults,
    String? searchQuery,
    Failure? failure,
    ProductEntity? lookupResult,
    bool clearFailure = false,
    bool clearLookupResult = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      inventoryMap: inventoryMap ?? this.inventoryMap,
      quickTileList: quickTileList ?? this.quickTileList,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      failure: clearFailure ? null : failure ?? this.failure,
      lookupResult: clearLookupResult ? null : lookupResult ?? this.lookupResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          inventoryMap == other.inventoryMap &&
          quickTileList == other.quickTileList &&
          searchResults == other.searchResults &&
          searchQuery == other.searchQuery &&
          failure == other.failure &&
          lookupResult == other.lookupResult;

  @override
  int get hashCode =>
      status.hashCode ^
      inventoryMap.hashCode ^
      quickTileList.hashCode ^
      searchResults.hashCode ^
      searchQuery.hashCode ^
      failure.hashCode ^
      lookupResult.hashCode;
}
