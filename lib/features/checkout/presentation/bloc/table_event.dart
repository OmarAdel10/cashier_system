import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_order_line.dart';

sealed class TablesEvent {
  const TablesEvent();
}

final class LoadTables extends TablesEvent {
  const LoadTables();
}

final class SaveTable extends TablesEvent {
  final TableEntity table;
  const SaveTable(this.table);
}

final class DeleteTable extends TablesEvent {
  final String tableId;
  const DeleteTable(this.tableId);
}

final class OpenTab extends TablesEvent {
  final String tableId;
  const OpenTab(this.tableId);
}

final class UpdateDraftLines extends TablesEvent {
  final String tableId;
  final List<TableOrderLine> lines;
  const UpdateDraftLines(this.tableId, this.lines);
}

final class FireRound extends TablesEvent {
  final String tableId;
  const FireRound(this.tableId);
}

final class MarkServed extends TablesEvent {
  final String tableId;
  final String roundId;
  const MarkServed(this.tableId, this.roundId);
}

final class StartCheckout extends TablesEvent {
  final String tableId;
  const StartCheckout(this.tableId);
}

final class CompleteCheckout extends TablesEvent {
  final String tableId;
  const CompleteCheckout(this.tableId);
}

final class TransferTable extends TablesEvent {
  final String sourceId;
  final String targetId;
  const TransferTable(this.sourceId, this.targetId);
}

final class MergeTables extends TablesEvent {
  final String sourceId;
  final String targetId;
  const MergeTables(this.sourceId, this.targetId);
}

final class ClearTab extends TablesEvent {
  final String tableId;
  const ClearTab(this.tableId);
}
