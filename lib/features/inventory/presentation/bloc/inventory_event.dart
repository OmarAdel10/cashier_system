import '../../domain/entities/product_entity.dart';

sealed class InventoryEvent {
  const InventoryEvent();
}

final class LoadInventory extends InventoryEvent {
  const LoadInventory();
}

final class AddProduct extends InventoryEvent {
  final String barcode;
  final String name;
  final double price;
  final double purchasePrice;
  final int stock;
  final bool isQuickTile;
  final String? tileColorHex;
  final String notes;
  final String? category;
  final PrepCategory prepCategory;

  const AddProduct({
    required this.barcode,
    required this.name,
    this.price = 0.0,
    this.purchasePrice = 0.0,
    this.stock = 0,
    this.isQuickTile = false,
    this.tileColorHex,
    this.notes = '',
    this.category,
    this.prepCategory = PrepCategory.food,
  });
}

final class ToggleQuickTile extends InventoryEvent {
  final String barcode;
  const ToggleQuickTile({required this.barcode});
}

final class UpdateTileColor extends InventoryEvent {
  final String barcode;
  final String colorHex;
  const UpdateTileColor({required this.barcode, required this.colorHex});
}

final class SearchProducts extends InventoryEvent {
  final String query;
  const SearchProducts(this.query);
}

final class DeleteProduct extends InventoryEvent {
  final String barcode;
  const DeleteProduct(this.barcode);
}

final class LookupProduct extends InventoryEvent {
  final String barcode;
  const LookupProduct(this.barcode);
}

final class RefreshInventory extends InventoryEvent {
  const RefreshInventory();
}
