import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:cashier_system/features/inventory/domain/repositories/i_inventory_repository.dart';

class FakeInventoryRepository implements IInventoryRepository {
  final _inventory = <String, ProductEntity>{};

  @override
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory() async {
    return Right(Map.from(_inventory));
  }

  @override
  Future<Either<Failure, void>> saveProduct(ProductEntity product) async {
    _inventory[product.barcode] = product;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateProduct(
    String oldBarcode,
    ProductEntity product,
  ) async {
    if (oldBarcode == product.barcode) {
      return saveProduct(product);
    }
    if (_inventory.containsKey(product.barcode)) {
      return Left(
        DatabaseFailure(
          'Product already exists with barcode ${product.barcode}',
        ),
      );
    }
    _inventory.remove(oldBarcode);
    _inventory[product.barcode] = product;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String barcode) async {
    _inventory.remove(barcode);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles() async {
    return Right(_inventory.values.where((p) => p.isQuickTile).toList());
  }

  @override
  Future<Either<Failure, void>> toggleQuickTile(String barcode) async {
    final p = _inventory[barcode];
    if (p == null)
      return Left(
        ItemNotFoundFailure('Product not found: $barcode', barcode: barcode),
      );
    _inventory[barcode] = p.copyWith(isQuickTile: !p.isQuickTile);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateTileColor(
    String barcode,
    String colorHex,
  ) async {
    final p = _inventory[barcode];
    if (p == null)
      return Left(
        ItemNotFoundFailure('Product not found: $barcode', barcode: barcode),
      );
    _inventory[barcode] = p.copyWith(tileColorHex: colorHex);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateStock(
    String barcode,
    int deltaQuantity,
  ) async {
    final p = _inventory[barcode];
    if (p == null)
      return Left(
        ItemNotFoundFailure('Product not found: $barcode', barcode: barcode),
      );
    _inventory[barcode] = p.copyWith(stock: p.stock + deltaQuantity);
    return const Right(null);
  }
}
