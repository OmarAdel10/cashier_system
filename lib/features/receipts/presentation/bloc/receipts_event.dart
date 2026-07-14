import '../../domain/entities/receipt_item.dart';

sealed class ReceiptsEvent {
  const ReceiptsEvent();
}

class CreateReceipt extends ReceiptsEvent {
  final String shiftId;
  final String orderNumber;
  final List<ReceiptItem> items;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;
  final String username;

  const CreateReceipt({
    required this.shiftId,
    required this.orderNumber,
    required this.items,
    required this.subtotalPiastres,
    this.discountPiastres = 0,
    this.taxPiastres = 0,
    required this.totalPiastres,
    required this.username,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateReceipt &&
          runtimeType == other.runtimeType &&
          shiftId == other.shiftId &&
          orderNumber == other.orderNumber &&
          subtotalPiastres == other.subtotalPiastres &&
          discountPiastres == other.discountPiastres &&
          taxPiastres == other.taxPiastres &&
          totalPiastres == other.totalPiastres &&
          username == other.username;

  @override
  int get hashCode => Object.hash(shiftId, orderNumber, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, username);
}

class LoadReceipts extends ReceiptsEvent {
  const LoadReceipts();

  @override
  bool operator ==(Object other) => identical(this, other) || other is LoadReceipts;
  @override
  int get hashCode => 0;
}

class LoadReceiptsByMonth extends ReceiptsEvent {
  final int year;
  final int month;
  const LoadReceiptsByMonth({required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadReceiptsByMonth && year == other.year && month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}
