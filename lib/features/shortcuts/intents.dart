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

class EditCartItemQuantityIntent extends Intent {
  const EditCartItemQuantityIntent();
}

class SetAmountPaid5EGIntent extends Intent {
  const SetAmountPaid5EGIntent();
}
class SetAmountPaid10EGIntent extends Intent {
  const SetAmountPaid10EGIntent();
}
class SetAmountPaid20EGIntent extends Intent {
  const SetAmountPaid20EGIntent();
}
class SetAmountPaid50EGIntent extends Intent {
  const SetAmountPaid50EGIntent();
}
class SetAmountPaid100EGIntent extends Intent {
  const SetAmountPaid100EGIntent();
}
class SetAmountPaid200EGIntent extends Intent {
  const SetAmountPaid200EGIntent();
}

class ClearAmountPaidIntent extends Intent {
  const ClearAmountPaidIntent();
}

class ClearSearchIntent extends Intent {
  const ClearSearchIntent();
}

class NullIntent extends Intent {
  const NullIntent();
}
