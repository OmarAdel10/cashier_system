import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

enum RoundStatus { pendingKitchen, prepared, served }

class TableRoundEntity {
  final String id;
  final String tableId;
  final int roundNumber;
  final List<TableOrderLine> lines;
  final DateTime firedAt;
  final RoundStatus status;

  const TableRoundEntity({
    required this.id,
    required this.tableId,
    required this.roundNumber,
    required this.lines,
    required this.firedAt,
    this.status = RoundStatus.pendingKitchen,
  });

  static const _unset = Object();

  TableRoundEntity copyWith({
    String? id,
    String? tableId,
    int? roundNumber,
    List<TableOrderLine>? lines,
    Object? firedAt = _unset,
    RoundStatus? status,
  }) {
    return TableRoundEntity(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      roundNumber: roundNumber ?? this.roundNumber,
      lines: lines ?? this.lines,
      firedAt: identical(firedAt, _unset) ? this.firedAt : firedAt as DateTime,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableRoundEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tableId == other.tableId &&
          roundNumber == other.roundNumber &&
          _listEquals(lines, other.lines) &&
          firedAt == other.firedAt &&
          status == other.status;

  static bool _listEquals(List<TableOrderLine> a, List<TableOrderLine> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      tableId.hashCode ^
      roundNumber.hashCode ^
      Object.hashAll(lines) ^
      firedAt.hashCode ^
      status.hashCode;
}
