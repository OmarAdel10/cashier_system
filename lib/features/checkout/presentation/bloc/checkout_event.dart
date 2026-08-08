sealed class CheckoutEvent {
  const CheckoutEvent();
}

final class AddToCart extends CheckoutEvent {
  final String barcode;
  final String name;
  final int unitPricePiastres;

  const AddToCart({
    required this.barcode,
    required this.name,
    required this.unitPricePiastres,
  });
}

final class UpdateQuantity extends CheckoutEvent {
  final String barcode;
  final int quantity;

  const UpdateQuantity({required this.barcode, required this.quantity});
}

final class RemoveFromCart extends CheckoutEvent {
  final String barcode;
  const RemoveFromCart(this.barcode);
}

final class ClearCart extends CheckoutEvent {
  const ClearCart();
}

final class SetAmountPaid extends CheckoutEvent {
  final int piastres;
  const SetAmountPaid(this.piastres);
}

final class ConfirmSale extends CheckoutEvent {
  const ConfirmSale();
}

final class ClearAmountPaid extends CheckoutEvent {
  const ClearAmountPaid();
}

final class SetDiscount extends CheckoutEvent {
  final int percent;
  const SetDiscount(this.percent);
}

final class SetTaxPercent extends CheckoutEvent {
  final int percent;
  const SetTaxPercent(this.percent);
}

final class SetPaymentType extends CheckoutEvent {
  final String typeId;
  const SetPaymentType(this.typeId);
}
