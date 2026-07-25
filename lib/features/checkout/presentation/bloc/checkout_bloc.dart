import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/licensing/engine/license_engine.dart';
import '../../domain/entities/cart_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import 'checkout_event.dart';
import 'checkout_state.dart';

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  final String Function()? generateOrderNumber;
  final LicenseEngine? _licenseEngine;
  bool _confirmInProgress = false;

  CheckoutBloc({this.generateOrderNumber, LicenseEngine? licenseEngine})
      : _licenseEngine = licenseEngine,
        super(CheckoutState(status: CheckoutStatus.ready, cart: CartEntity.create())) {
    on<AddToCart>(_onAddToCart);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
    on<SetAmountPaid>(_onSetAmountPaid);
    on<ClearAmountPaid>(_onClearAmountPaid);
    on<ConfirmSale>(_onConfirmSale);
    on<SetDiscount>(_onSetDiscount);
    on<SetTaxPercent>(_onSetTaxPercent);
  }

  void _onAddToCart(AddToCart event, Emitter<CheckoutState> emit) {
    final cart = state.cart ?? CartEntity.create();
    final existingIndex = cart.items.indexWhere((i) => i.barcode == event.barcode);
    final List<CartItemEntity> updatedItems;

    if (existingIndex >= 0) {
      final existing = cart.items[existingIndex];
      updatedItems = [
        ...cart.items.sublist(0, existingIndex),
        existing.copyWith(quantity: existing.quantity + 1),
        ...cart.items.sublist(existingIndex + 1),
      ];
    } else {
      updatedItems = [
        ...cart.items,
        CartItemEntity(
          barcode: event.barcode,
          name: event.name,
          unitPricePiastres: event.unitPricePiastres,
        ),
      ];
    }

    emit(state.copyWith(
      status: CheckoutStatus.ready,
      cart: cart.copyWith(items: updatedItems),
      clearFailure: true,
    ));
  }

  void _onUpdateQuantity(UpdateQuantity event, Emitter<CheckoutState> emit) {
    final cart = state.cart;
    if (cart == null) return;

    final List<CartItemEntity> updatedItems;
    if (event.quantity <= 0) {
      updatedItems = cart.items.where((i) => i.barcode != event.barcode).toList();
    } else {
      final index = cart.items.indexWhere((i) => i.barcode == event.barcode);
      if (index < 0) return;
      updatedItems = [
        ...cart.items.sublist(0, index),
        cart.items[index].copyWith(quantity: event.quantity),
        ...cart.items.sublist(index + 1),
      ];
    }

    emit(state.copyWith(
      status: CheckoutStatus.ready,
      cart: cart.copyWith(items: updatedItems),
      clearAmountPaid: true,
    ));
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CheckoutState> emit) {
    final cart = state.cart;
    if (cart == null) return;

    emit(state.copyWith(
      status: CheckoutStatus.ready,
      cart: cart.copyWith(items: cart.items.where((i) => i.barcode != event.barcode).toList()),
      clearAmountPaid: true,
    ));
  }

  void _onClearCart(ClearCart event, Emitter<CheckoutState> emit) {
    _confirmInProgress = false;
    emit(CheckoutState(status: CheckoutStatus.ready, cart: CartEntity.create()));
  }

  void _onSetAmountPaid(SetAmountPaid event, Emitter<CheckoutState> emit) {
    if (event.piastres < 0) return;
    emit(state.copyWith(amountPaidPiastres: event.piastres));
  }

  void _onClearAmountPaid(ClearAmountPaid event, Emitter<CheckoutState> emit) {
    emit(state.copyWith(clearAmountPaid: true));
  }

  Future<void> _onConfirmSale(ConfirmSale event, Emitter<CheckoutState> emit) async {
    final cart = state.cart;
    if (cart == null || cart.isEmpty) return;
    if (_confirmInProgress) return;
    if (!state.isPaid) {
      emit(state.copyWith(
        status: CheckoutStatus.error,
        failure: const ValidationFailure(
          'Payment required before confirming sale',
          field: 'amountPaidPiastres',
          reason: 'insufficient_payment',
        ),
      ));
      return;
    }

    if (_licenseEngine != null) {
      final licensed = await _licenseEngine.quickVerify();
      if (!licensed) {
        _confirmInProgress = false;
        emit(state.copyWith(
          status: CheckoutStatus.error,
          failure: const DatabaseFailure('License verification failed. Contact support.'),
        ));
        return;
      }
    }

    _confirmInProgress = true;
    final orderNumber = generateOrderNumber != null ? generateOrderNumber!() : null;
    emit(state.copyWith(
      status: CheckoutStatus.confirmed,
      orderNumber: orderNumber,
    ));
  }

  void _onSetDiscount(SetDiscount event, Emitter<CheckoutState> emit) {
    final percent = event.percent.clamp(0, 100);
    emit(state.copyWith(
      discountPercent: percent,
      clearAmountPaid: true,
    ));
  }

  void _onSetTaxPercent(SetTaxPercent event, Emitter<CheckoutState> emit) {
    final percent = event.percent.clamp(0, 100);
    emit(state.copyWith(taxPercent: percent));
  }
}
