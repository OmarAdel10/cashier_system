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
  final int stock;
  final bool isQuickTile;
  final String? tileColorHex;

  const AddProduct({
    required this.barcode,
    required this.name,
    this.price = 0.0,
    this.stock = 0,
    this.isQuickTile = false,
    this.tileColorHex,
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
