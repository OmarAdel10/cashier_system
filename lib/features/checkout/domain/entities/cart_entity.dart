import 'dart:math';

import 'cart_item_entity.dart';

class CartEntity {
  final List<CartItemEntity> items;
  final String transactionId;

  const CartEntity({required this.items, required this.transactionId});

  factory CartEntity.create() {
    final now = DateTime.now();
    final micros = now.microsecondsSinceEpoch.toString();
    // Exactly 5 digits so they always survive the 15-char truncation below.
    final random = Random.secure().nextInt(100000).toString().padLeft(5, '0');
    final raw = '$micros$random';
    // Take the trailing 15 chars: 10 microsecond digits + all 5 random digits.
    // (Previously the leading 15 chars cut off the random digits, so two
    // creates within the same millisecond collided ~1% of the time.)
    final txId = raw.length >= 15
        ? raw.substring(raw.length - 15)
        : raw.padRight(15, '0');
    return CartEntity(items: const [], transactionId: txId);
  }

  int get subtotalPiastres =>
      items.fold(0, (sum, item) => sum + item.totalPiastres);

  bool get isEmpty => items.isEmpty;

  CartEntity copyWith({List<CartItemEntity>? items, String? transactionId}) {
    return CartEntity(
      items: items ?? this.items,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartEntity &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          transactionId == other.transactionId;

  @override
  int get hashCode => items.hashCode ^ transactionId.hashCode;
}
