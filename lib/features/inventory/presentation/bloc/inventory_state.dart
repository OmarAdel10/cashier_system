import '../../../../core/error/failure.dart';
import '../../domain/entities/product_entity.dart';

enum InventoryStatus { initial, loading, ready, error }

class ImportResult {
  final int created;
  final int updated;
  final int failed;
  final String? error;
  const ImportResult({
    required this.created,
    required this.updated,
    required this.failed,
    this.error,
  });
}

class InventoryState {
  final InventoryStatus status;
  final Map<String, ProductEntity> inventoryMap;
  final List<ProductEntity> quickTileList;
  final List<ProductEntity> searchResults;
  final String searchQuery;
  final Failure? failure;
  final ProductEntity? lookupResult;
  final ImportResult? importResult;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.inventoryMap = const {},
    this.quickTileList = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.failure,
    this.lookupResult,
    this.importResult,
  });

  InventoryState copyWith({
    InventoryStatus? status,
    Map<String, ProductEntity>? inventoryMap,
    List<ProductEntity>? quickTileList,
    List<ProductEntity>? searchResults,
    String? searchQuery,
    Failure? failure,
    ProductEntity? lookupResult,
    ImportResult? importResult,
    bool clearFailure = false,
    bool clearLookupResult = false,
    bool clearImportResult = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      inventoryMap: inventoryMap ?? this.inventoryMap,
      quickTileList: quickTileList ?? this.quickTileList,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      failure: clearFailure ? null : failure ?? this.failure,
      lookupResult: clearLookupResult
          ? null
          : lookupResult ?? this.lookupResult,
      importResult: clearImportResult
          ? null
          : importResult ?? this.importResult,
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
          lookupResult == other.lookupResult &&
          importResult == other.importResult;

  @override
  int get hashCode =>
      status.hashCode ^
      inventoryMap.hashCode ^
      quickTileList.hashCode ^
      searchResults.hashCode ^
      searchQuery.hashCode ^
      failure.hashCode ^
      lookupResult.hashCode ^
      importResult.hashCode;
}
