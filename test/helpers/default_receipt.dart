import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';

ReceiptEntity defaultReceipt({
  String id = 'test-receipt-id',
  String shiftId = 's1',
  String orderNumber = 'ORD-001',
  List<ReceiptItem> items = const [],
  int subtotalPiastres = 0,
  int discountPiastres = 0,
  int taxPiastres = 0,
  int totalPiastres = 0,
  DateTime? createdAt,
  String username = 'cashier1',
  bool stockUpdated = false,
  ReceiptStatus status = ReceiptStatus.active,
}) {
  return ReceiptEntity(
    id: id,
    shiftId: shiftId,
    orderNumber: orderNumber,
    items: items,
    subtotalPiastres: subtotalPiastres,
    discountPiastres: discountPiastres,
    taxPiastres: taxPiastres,
    totalPiastres: totalPiastres,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    username: username,
    stockUpdated: stockUpdated,
    status: status,
  );
}
