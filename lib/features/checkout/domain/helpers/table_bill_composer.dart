import '../../../checkout/domain/entities/table_order_line.dart';
import '../../../checkout/domain/entities/zone_entity.dart';
import '../../../receipts/domain/entities/receipt_item.dart';

/// A single composed table bill and its exact N-way splits.
class ComposedTableBill {
  final List<TableOrderLine> firedLines;
  final List<TableOrderLine> draftLines;
  final List<ReceiptItem> items;
  final int roomChargePiastres;
  final int serviceChargePiastres;
  final int minChargeDeltaPiastres;
  final int subtotalPiastres;
  final int discountPercent;
  final int discountPiastres;
  final int taxPercent;
  final int taxPiastres;
  final int totalPiastres;
  final String roomChargeLabel;
  final String serviceChargeLabel;
  final String minChargeLabel;

  const ComposedTableBill({
    required this.firedLines,
    required this.draftLines,
    required this.items,
    required this.roomChargePiastres,
    required this.serviceChargePiastres,
    required this.minChargeDeltaPiastres,
    required this.subtotalPiastres,
    required this.discountPercent,
    required this.discountPiastres,
    required this.taxPercent,
    required this.taxPiastres,
    required this.totalPiastres,
    this.roomChargeLabel = 'Room Rent',
    this.serviceChargeLabel = 'Service Charge',
    this.minChargeLabel = 'Minimum Charge',
  });

  /// Pure sum of ordered lines (before room/service/floor adjustments).
  int get itemsSum {
    var sum = 0;
    for (final line in supportedLines) {
      sum += line.quantity * line.unitPricePiastres;
    }
    return sum;
  }

  List<TableOrderLine> get supportedLines => [...firedLines, ...draftLines];

  /// Splits the bill into [count] receipts.
  ///
  /// Line quantities, room charge, service charge, min-charge delta,
  /// discount and tax are each divided with the remainder going to the
  /// LAST receipt. Every receipt satisfies the receipts-bloc financial
  /// validation exactly: items sum == subtotal and
  /// total == subtotal - discount + tax.
  List<TableBillSplit> split(int count) {
    if (count <= 0) return const [];
    if (count == 1) {
      return [
        TableBillSplit(
          items: List.of(items),
          subtotalPiastres: subtotalPiastres,
          discountPiastres: discountPiastres,
          taxPiastres: taxPiastres,
          totalPiastres: totalPiastres,
        ),
      ];
    }

    final splits = List.generate(
      count,
      (_) => TableBillSplit(
        items: [],
        subtotalPiastres: 0,
        discountPiastres: 0,
        taxPiastres: 0,
        totalPiastres: 0,
      ),
    );

    // Order lines: divide quantities, remainder to last receipt.
    for (final line in supportedLines) {
      final each = line.quantity ~/ count;
      final remainder = line.quantity % count;
      for (var i = 0; i < count; i++) {
        final qty = i == count - 1 ? each + remainder : each;
        if (qty == 0) continue;
        splits[i].items.add(
          ReceiptItem(
            name: line.name,
            barcode: line.barcode,
            quantity: qty,
            unitPricePiastres: line.unitPricePiastres,
          ),
        );
      }
    }

    // Extras (room / service / min-charge delta): split amounts, remainder
    // to last receipt, each as its own single-quantity item so the items
    // sum validation still holds per receipt.
    _addSplitExtras(splits, count, roomChargePiastres, roomChargeLabel);
    _addSplitExtras(splits, count, serviceChargePiastres, serviceChargeLabel);
    _addSplitExtras(splits, count, minChargeDeltaPiastres, minChargeLabel);

    // Discount and tax: split amounts, remainder to last receipt.
    final discountParts = splitAmount(discountPiastres, count);
    final taxParts = splitAmount(taxPiastres, count);
    for (var i = 0; i < count; i++) {
      final split = splits[i];
      split.discountPiastres = discountParts[i];
      split.taxPiastres = taxParts[i];
      var subtotal = 0;
      for (final item in split.items) {
        subtotal += item.quantity * item.unitPricePiastres;
      }
      split.subtotalPiastres = subtotal;
      split.totalPiastres =
          subtotal - split.discountPiastres + split.taxPiastres;
    }
    return splits;
  }

  /// Splits [amount] into [count] integer parts; the remainder is added to
  /// the last part.
  static List<int> splitAmount(int amount, int count) {
    if (count <= 0) return const [];
    final each = amount ~/ count;
    final remainder = amount % count;
    return List.generate(
      count,
      (i) => i == count - 1 ? each + remainder : each,
    );
  }
}

/// One receipt of a split table bill.
class TableBillSplit {
  final List<ReceiptItem> items;
  int subtotalPiastres;
  int discountPiastres;
  int taxPiastres;
  int totalPiastres;

  TableBillSplit({
    required this.items,
    required this.subtotalPiastres,
    required this.discountPiastres,
    required this.taxPiastres,
    required this.totalPiastres,
  });
}

/// Composes a table bill following the cafe-mode chain:
/// base (fired + draft lines + room charge) -> min-charge floor
/// (dine-in zones only) -> service charge percent (dine-in zones only)
/// -> retail-parity discount and tax (mirrors CheckoutState math).
class TableBillComposer {
  final ZoneKind zoneKind;
  final bool isRoom;
  final int chargedHours;
  final int hourlyRatePiastres;
  final List<TableOrderLine> firedLines;
  final List<TableOrderLine> draftLines;
  final bool minChargeEnabled;
  final int minChargePerTablePiastres;
  final bool serviceChargeEnabled;
  final int serviceChargePercent;
  final int discountPercent;
  final int taxPercent;
  final String roomChargeLabel;
  final String serviceChargeLabel;
  final String minChargeLabel;

  TableBillComposer({
    this.zoneKind = ZoneKind.takeaway,
    this.isRoom = false,
    this.chargedHours = 0,
    this.hourlyRatePiastres = 0,
    this.firedLines = const [],
    this.draftLines = const [],
    this.minChargeEnabled = false,
    this.minChargePerTablePiastres = 0,
    this.serviceChargeEnabled = false,
    this.serviceChargePercent = 12,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.roomChargeLabel = 'Room Rent',
    this.serviceChargeLabel = 'Service Charge',
    this.minChargeLabel = 'Minimum Charge',
  });

  bool get _isDineIn => zoneKind == ZoneKind.dineIn;

  ComposedTableBill compose() {
    final allLines = [...firedLines, ...draftLines];
    final baseItems = <ReceiptItem>[];
    var itemsSum = 0;
    for (final line in allLines) {
      itemsSum += line.quantity * line.unitPricePiastres;
      baseItems.add(
        ReceiptItem(
          name: line.name,
          barcode: line.barcode,
          quantity: line.quantity,
          unitPricePiastres: line.unitPricePiastres,
        ),
      );
    }

    var subtotal = itemsSum;

    // Room charge: charged hours are always at least 1
    // (mirrors TableEntity.chargedHours).
    final effectiveHours = chargedHours < 1 ? 1 : chargedHours;
    final roomTotal = isRoom ? effectiveHours * hourlyRatePiastres : 0;
    subtotal += roomTotal;
    if (roomTotal > 0) {
      baseItems.add(
        ReceiptItem(
          name: roomChargeLabel,
          barcode: '',
          quantity: 1,
          unitPricePiastres: roomTotal,
        ),
      );
    }

    // Min-charge floor (dine-in zones only).
    var minDelta = 0;
    if (_isDineIn && minChargeEnabled && subtotal < minChargePerTablePiastres) {
      minDelta = minChargePerTablePiastres - subtotal;
      subtotal += minDelta;
      baseItems.add(
        ReceiptItem(
          name: minChargeLabel,
          barcode: '',
          quantity: 1,
          unitPricePiastres: minDelta,
        ),
      );
    }

    // Service charge percent (dine-in zones only).
    var service = 0;
    if (_isDineIn && serviceChargeEnabled) {
      service = (subtotal * serviceChargePercent / 100).round();
      subtotal += service;
      baseItems.add(
        ReceiptItem(
          name: serviceChargeLabel,
          barcode: '',
          quantity: 1,
          unitPricePiastres: service,
        ),
      );
    }

    // Retail-parity discount and tax (mirrors CheckoutState).
    final clampedDiscount = discountPercent.clamp(0, 100);
    final discount = (subtotal * clampedDiscount / 100).round();
    final tax = (subtotal * taxPercent / 100).round();
    final total = subtotal - discount + tax;

    return ComposedTableBill(
      firedLines: firedLines,
      draftLines: draftLines,
      items: baseItems,
      roomChargePiastres: roomTotal,
      serviceChargePiastres: service,
      minChargeDeltaPiastres: minDelta,
      subtotalPiastres: subtotal,
      discountPercent: clampedDiscount,
      discountPiastres: discount,
      taxPercent: taxPercent,
      taxPiastres: tax,
      totalPiastres: total,
      roomChargeLabel: roomChargeLabel,
      serviceChargeLabel: serviceChargeLabel,
      minChargeLabel: minChargeLabel,
    );
  }
}

void _addSplitExtras(
  List<TableBillSplit> splits,
  int count,
  int amount,
  String name,
) {
  if (amount <= 0) return;
  final parts = ComposedTableBill.splitAmount(amount, count);
  for (var i = 0; i < count; i++) {
    if (parts[i] == 0) continue;
    splits[i].items.add(
      ReceiptItem(
        name: name,
        barcode: '',
        quantity: 1,
        unitPricePiastres: parts[i],
      ),
    );
  }
}
