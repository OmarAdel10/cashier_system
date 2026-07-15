import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';

ProductEntity defaultProduct({
  required String barcode,
  required String name,
  int stock = 0,
}) {
  return ProductEntity(
    barcode: barcode,
    name: name,
    price: 0,
    stock: stock,
  );
}
