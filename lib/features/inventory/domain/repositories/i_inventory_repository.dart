import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/product_entity.dart';

abstract class IInventoryRepository {
  Future<Either<Failure, Map<String, ProductEntity>>> getInventory();
  Future<Either<Failure, void>> saveProduct(ProductEntity product);
  Future<Either<Failure, void>> deleteProduct(String barcode);
  Future<Either<Failure, List<ProductEntity>>> getQuickTiles();
  Future<Either<Failure, void>> toggleQuickTile(String barcode);
  Future<Either<Failure, void>> updateTileColor(String barcode, String colorHex);
}
