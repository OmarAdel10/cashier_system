import 'package:flutter/foundation.dart';
import 'receipt_item.dart';
import 'receipt_status.dart';

class ReceiptEntity {
  final String id;
  final String shiftId;
  final String orderNumber;
  final List<ReceiptItem> items;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;
  final DateTime createdAt;
  final String username;
  final bool stockUpdated;
  final List<String> stockFailedBarcodes;
  final ReceiptStatus status;
  final int modificationCount;

  const ReceiptEntity({
    required this.id,
    required this.shiftId,
    required this.orderNumber,
    required this.items,
    required this.subtotalPiastres,
    this.discountPiastres = 0,
    this.taxPiastres = 0,
    required this.totalPiastres,
    required this.createdAt,
    required this.username,
    this.stockUpdated = false,
    this.stockFailedBarcodes = const [],
    this.status = ReceiptStatus.active,
    this.modificationCount = 0,
  });

  ReceiptEntity copyWith({
    String? id, String? shiftId, String? orderNumber, List<ReceiptItem>? items,
    int? subtotalPiastres, int? discountPiastres, int? taxPiastres, int? totalPiastres,
    DateTime? createdAt, String? username, bool? stockUpdated, List<String>? stockFailedBarcodes,
    ReceiptStatus? status, int? modificationCount,
    bool clearStockUpdated = false,
    bool clearStockFailedBarcodes = false,
  }) {
    return ReceiptEntity(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      subtotalPiastres: subtotalPiastres ?? this.subtotalPiastres,
      discountPiastres: discountPiastres ?? this.discountPiastres,
      taxPiastres: taxPiastres ?? this.taxPiastres,
      totalPiastres: totalPiastres ?? this.totalPiastres,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      stockUpdated: clearStockUpdated ? false : (stockUpdated ?? this.stockUpdated),
      stockFailedBarcodes: clearStockFailedBarcodes ? const [] : (stockFailedBarcodes ?? this.stockFailedBarcodes),
      status: status ?? this.status,
      modificationCount: modificationCount ?? this.modificationCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shiftId == other.shiftId &&
          orderNumber == other.orderNumber &&
          subtotalPiastres == other.subtotalPiastres &&
          discountPiastres == other.discountPiastres &&
          taxPiastres == other.taxPiastres &&
          totalPiastres == other.totalPiastres &&
          createdAt == other.createdAt &&
          username == other.username &&
          stockUpdated == other.stockUpdated &&
          listEquals(stockFailedBarcodes, other.stockFailedBarcodes) &&
          status == other.status &&
          modificationCount == other.modificationCount;

  @override
  int get hashCode => Object.hash(id, shiftId, orderNumber, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, createdAt, username, stockUpdated, Object.hashAll(stockFailedBarcodes), status, modificationCount);

  @override
  String toString() => 'ReceiptEntity(id: $id, orderNumber: $orderNumber, status: $status, stockUpdated: $stockUpdated, stockFailedBarcodes: $stockFailedBarcodes, modificationCount: $modificationCount)';
}
