import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/i_inventory_repository.dart';
import '../models/app_product_model.dart';

class InventoryRepository implements IInventoryRepository {
  final Box<AppProductModel> _box;
  InventoryRepository({required Box<AppProductModel> box}) : _box = box;

  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async {
    try {
      final map = <String, ProductEntity>{};
      for (final key in _box.keys) {
        final model = _box.get(key);
        if (model != null) {
          map[key as String] = model.toEntity();
        }
      }
      return Right(map);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load inventory'));
    }
  }

  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async {
    try {
      final model = AppProductModel(
        barcode: product.barcode,
        name: product.name,
        price: product.price,
        purchasePrice: product.purchasePrice,
        stock: product.stock,
        isQuickTile: product.isQuickTile,
        tileColorHex: product.tileColorHex,
      );
      await _box.put(product.barcode, model);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to save product'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async {
    try {
      await _box.delete(barcode);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to delete product'));
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async {
    try {
      final tiles = <ProductEntity>[];
      for (final key in _box.keys) {
        final model = _box.get(key);
        if (model != null && model.isQuickTile) {
          tiles.add(model.toEntity());
        }
      }
      return Right(tiles);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load quick tiles'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async {
    try {
      final model = _box.get(barcode);
      if (model == null) {
        return Left(ItemNotFoundFailure('Product not found: $barcode', barcode: barcode));
      }
      final updated = AppProductModel(
        barcode: model.barcode,
        name: model.name,
        price: model.price,
        purchasePrice: model.purchasePrice,
        stock: model.stock,
        isQuickTile: !model.isQuickTile,
        tileColorHex: model.isQuickTile ? null : model.tileColorHex,
      );
      await _box.put(barcode, updated);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to toggle quick tile'));
    }
  }

  @override
  Future<Either<Failure, void>> updateTileColor(String barcode, String colorHex) async {
    try {
      final model = _box.get(barcode);
      if (model == null) {
        return Left(ItemNotFoundFailure('Product not found: $barcode', barcode: barcode));
      }
      final updated = AppProductModel(
        barcode: model.barcode,
        name: model.name,
        price: model.price,
        purchasePrice: model.purchasePrice,
        stock: model.stock,
        isQuickTile: model.isQuickTile,
        tileColorHex: colorHex,
      );
      await _box.put(barcode, updated);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to update tile color'));
    }
  }

  @override
  Future<Either<Failure, void>> updateStock(String barcode, int deltaQuantity) async {
    try {
      final model = _box.get(barcode);
      if (model == null) {
        return Left(ItemNotFoundFailure('Product not found: $barcode', barcode: barcode));
      }
      final newStock = model.stock + deltaQuantity;
      if (newStock < 0) {
        return Left(
          DatabaseFailure('Insufficient stock for ${model.barcode}'),
        );
      }
      final updated = AppProductModel(
        barcode: model.barcode,
        name: model.name,
        price: model.price,
        purchasePrice: model.purchasePrice,
        stock: newStock,
        isQuickTile: model.isQuickTile,
        tileColorHex: model.tileColorHex,
      );
      await _box.put(barcode, updated);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to update stock'));
    }
  }
}
