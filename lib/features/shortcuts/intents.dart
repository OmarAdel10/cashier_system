import 'package:flutter/widgets.dart';

class NavigateToCheckoutIntent extends Intent {
  const NavigateToCheckoutIntent();
}
class NavigateToInventoryIntent extends Intent {
  const NavigateToInventoryIntent();
}
class NavigateToSalesIntent extends Intent {
  const NavigateToSalesIntent();
}
class NavigateToSettingsIntent extends Intent {
  const NavigateToSettingsIntent();
}

class ToggleSearchOverlayIntent extends Intent {
  const ToggleSearchOverlayIntent();
}

class SelectNextCartItemIntent extends Intent {
  const SelectNextCartItemIntent();
}
class SelectPrevCartItemIntent extends Intent {
  const SelectPrevCartItemIntent();
}
class RemoveSelectedCartItemIntent extends Intent {
  const RemoveSelectedCartItemIntent();
}
class ConfirmSaleIntent extends Intent {
  const ConfirmSaleIntent();
}

class ActivateQuickTileIntent extends Intent {
  final int tileIndex;
  const ActivateQuickTileIntent(this.tileIndex);
}

class AddProductIntent extends Intent {
  const AddProductIntent();
}

class FocusDiscountIntent extends Intent {
  const FocusDiscountIntent();
}
