import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_state.dart';
import '../../../../helpers/fake_license_engine.dart';

void main() {
  late CheckoutBloc bloc;

  setUp(() {
    bloc = CheckoutBloc();
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have ready status with empty cart', () {
      expect(bloc.state.status, CheckoutStatus.ready);
      expect(bloc.state.cart, isNotNull);
      expect(bloc.state.cart!.isEmpty, isTrue);
    });
  });

  group('AddToCart', () {
    test('should create cart and add first item', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.status == CheckoutStatus.ready &&
              s.cart != null &&
              s.cart!.items.length == 1 &&
              s.cart!.items.first.name == 'Pen'),
        ),
      );
    });

    test('should increment quantity for existing item', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.cart!.items.length == 1 && s.cart!.items.first.quantity == 2),
        ),
      );
    });

    test('should add different items separately', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const AddToCart(barcode: '222', name: 'Notebook', unitPricePiastres: 2500));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) => s.cart!.items.length == 2),
        ),
      );
    });
  });

  group('UpdateQuantity', () {
    test('should update quantity of existing item', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const UpdateQuantity(barcode: '111', quantity: 5));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.cart!.items.first.quantity == 5 &&
              s.amountPaidPiastres == null),
        ),
      );
    });

    test('should remove item when quantity is 0', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const UpdateQuantity(barcode: '111', quantity: 0));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) => s.cart!.items.isEmpty),
        ),
      );
    });
  });

  group('RemoveFromCart', () {
    test('should remove item from cart', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const RemoveFromCart('111'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) => s.cart!.items.isEmpty),
        ),
      );
    });
  });

  group('ClearCart', () {
    test('should clear cart and create new transaction', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;
      final oldTxId = bloc.state.cart!.transactionId;

      bloc.add(const ClearCart());

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.cart!.items.isEmpty &&
              s.cart!.transactionId != oldTxId),
        ),
      );
    });
  });

  group('SetAmountPaid', () {
    test('should calculate change correctly', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const SetAmountPaid(2000));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.amountPaidPiastres == 2000 &&
              s.changePiastres == 500 &&
              s.isPaid == true),
        ),
      );
    });

    test('should not be paid when amount is insufficient', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const SetAmountPaid(1000));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.isPaid == false && s.changePiastres == 0),
        ),
      );
    });

    test('should ignore negative amounts', () async {
      bloc.add(const SetAmountPaid(-100));
      expect(bloc.state.amountPaidPiastres, isNull);
    });
  });

  group('ConfirmSale', () {
    test('should emit confirmed when paid and cart not empty', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;
      bloc.add(const SetAmountPaid(1500));
      await bloc.stream.first;

      bloc.add(const ConfirmSale());

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) => s.status == CheckoutStatus.confirmed),
        ),
      );
    });

    test('should reject sale when not paid', () async {
      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;

      bloc.add(const ConfirmSale());

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.status == CheckoutStatus.error &&
              s.failure is ValidationFailure),
        ),
      );
    });

    test('should not confirm empty cart', () async {
      bloc.add(const ConfirmSale());
      expect(bloc.state.status, isNot(CheckoutStatus.confirmed));
    });
  });

  group('license verification', () {
    test('should block sale when license fails', () async {
      final failingLicense = FakeLicenseEngine(quickVerifyResult: false);
      bloc = CheckoutBloc(licenseEngine: failingLicense);

      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;
      bloc.add(const SetAmountPaid(1500));
      await bloc.stream.first;

      bloc.add(const ConfirmSale());

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) =>
              s.status == CheckoutStatus.error &&
              s.failure is DatabaseFailure),
        ),
      );
    });

    test('should allow sale when license passes', () async {
      final passingLicense = FakeLicenseEngine(quickVerifyResult: true);
      bloc = CheckoutBloc(licenseEngine: passingLicense);

      bloc.add(const AddToCart(barcode: '111', name: 'Pen', unitPricePiastres: 1500));
      await bloc.stream.first;
      bloc.add(const SetAmountPaid(1500));
      await bloc.stream.first;

      bloc.add(const ConfirmSale());

      await expectLater(
        bloc.stream,
        emits(
          predicate<CheckoutState>((s) => s.status == CheckoutStatus.confirmed),
        ),
      );
    });
  });
}
