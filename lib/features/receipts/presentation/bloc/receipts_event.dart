import '../../domain/entities/receipt_entity.dart';
import '../../domain/entities/receipt_item.dart';
import '../../domain/entities/refund_entity.dart';

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
  final int taxPercent;
  final int discountPercent;

  const CreateReceipt({
    required this.shiftId,
    required this.orderNumber,
    required this.items,
    required this.subtotalPiastres,
    this.discountPiastres = 0,
    this.taxPiastres = 0,
    required this.totalPiastres,
    required this.username,
    this.taxPercent = 0,
    this.discountPercent = 0,
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
          username == other.username &&
          taxPercent == other.taxPercent &&
          discountPercent == other.discountPercent;

  @override
  int get hashCode => Object.hash(shiftId, orderNumber, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, username, taxPercent, discountPercent);
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

class ProcessRefund extends ReceiptsEvent {
  final ReceiptEntity receipt;
  final RefundType type;
  final int amountRestored;

  const ProcessRefund({
    required this.receipt,
    required this.type,
    required this.amountRestored,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessRefund &&
          runtimeType == other.runtimeType &&
          receipt == other.receipt &&
          type == other.type &&
          amountRestored == other.amountRestored;

  @override
  int get hashCode => Object.hash(receipt, type, amountRestored);
}

class AuthorizedModifyReceipt extends ReceiptsEvent {
  final ReceiptEntity receipt;
  final List<ReceiptItem> items;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;
  final String adminUsername;
  final String adminPassword;

  const AuthorizedModifyReceipt({
    required this.receipt,
    required this.items,
    required this.subtotalPiastres,
    required this.discountPiastres,
    required this.taxPiastres,
    required this.totalPiastres,
    required this.adminUsername,
    required this.adminPassword,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorizedModifyReceipt &&
          runtimeType == other.runtimeType &&
          receipt == other.receipt &&
          subtotalPiastres == other.subtotalPiastres &&
          discountPiastres == other.discountPiastres &&
          taxPiastres == other.taxPiastres &&
          totalPiastres == other.totalPiastres &&
          adminUsername == other.adminUsername &&
          adminPassword == other.adminPassword;

  @override
  int get hashCode => Object.hash(receipt, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, adminUsername, adminPassword);
}

class ModifyReceipt extends ReceiptsEvent {
  final ReceiptEntity receipt;
  final List<ReceiptItem> items;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;

  const ModifyReceipt({
    required this.receipt,
    required this.items,
    required this.subtotalPiastres,
    required this.discountPiastres,
    required this.taxPiastres,
    required this.totalPiastres,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifyReceipt &&
          runtimeType == other.runtimeType &&
          receipt == other.receipt &&
          subtotalPiastres == other.subtotalPiastres &&
          discountPiastres == other.discountPiastres &&
          taxPiastres == other.taxPiastres &&
          totalPiastres == other.totalPiastres;

  @override
  int get hashCode => Object.hash(receipt, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres);
}
