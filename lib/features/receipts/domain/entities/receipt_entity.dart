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
  final ReceiptStatus status;

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
    this.status = ReceiptStatus.active,
  });

  ReceiptEntity copyWith({
    String? id, String? shiftId, String? orderNumber, List<ReceiptItem>? items,
    int? subtotalPiastres, int? discountPiastres, int? taxPiastres, int? totalPiastres,
    DateTime? createdAt, String? username, bool? stockUpdated, ReceiptStatus? status,
    bool clearStockUpdated = false,
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
      status: status ?? this.status,
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
          status == other.status;

  @override
  int get hashCode => Object.hash(id, shiftId, orderNumber, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, createdAt, username, stockUpdated, status);

  @override
  String toString() => 'ReceiptEntity(id: $id, orderNumber: $orderNumber, status: $status, stockUpdated: $stockUpdated)';
}
