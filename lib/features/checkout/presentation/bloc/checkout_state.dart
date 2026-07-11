import '../../../../core/error/failure.dart';
import '../../domain/entities/cart_entity.dart';

enum CheckoutStatus { initial, ready, error, confirmed }

class CheckoutState {
  final CheckoutStatus status;
  final CartEntity? cart;
  final int? amountPaidPiastres;
  final Failure? failure;
  final int discountPercent;
  final String? orderNumber;

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.cart,
    this.amountPaidPiastres,
    this.failure,
    this.discountPercent = 0,
    this.orderNumber,
  });

  int get subtotalPiastres => cart?.subtotalPiastres ?? 0;
  int get discountAmount => (subtotalPiastres * discountPercent / 100).round();
  int get afterDiscountPiastres => subtotalPiastres - discountAmount;

  int get changePiastres {
    if (amountPaidPiastres == null) return 0;
    final change = amountPaidPiastres! - afterDiscountPiastres;
    return change > 0 ? change : 0;
  }

  bool get isPaid =>
      amountPaidPiastres != null && amountPaidPiastres! >= afterDiscountPiastres;

  CheckoutState copyWith({
    CheckoutStatus? status,
    CartEntity? cart,
    int? amountPaidPiastres,
    Failure? failure,
    bool clearFailure = false,
    bool clearAmountPaid = false,
    int? discountPercent,
    String? orderNumber,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      cart: cart ?? this.cart,
      amountPaidPiastres: clearAmountPaid ? null : amountPaidPiastres ?? this.amountPaidPiastres,
      failure: clearFailure ? null : failure ?? this.failure,
      discountPercent: discountPercent ?? this.discountPercent,
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          cart == other.cart &&
          amountPaidPiastres == other.amountPaidPiastres &&
          failure == other.failure &&
          discountPercent == other.discountPercent &&
          orderNumber == other.orderNumber;

  @override
  int get hashCode =>
      status.hashCode ^
      cart.hashCode ^
      amountPaidPiastres.hashCode ^
      failure.hashCode ^
      discountPercent.hashCode ^
      orderNumber.hashCode;
}
