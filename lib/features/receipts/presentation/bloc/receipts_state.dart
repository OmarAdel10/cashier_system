import '../../../../core/error/failure.dart';
import '../../domain/entities/receipt_entity.dart';

enum ReceiptBlocStatus { initial, loading, ready, error }

class ReceiptsState {
  final ReceiptBlocStatus status;
  final List<ReceiptEntity> receipts;
  final Failure? failure;
  final bool receiptCreated;

  const ReceiptsState({
    this.status = ReceiptBlocStatus.initial,
    this.receipts = const [],
    this.failure,
    this.receiptCreated = false,
  });

  ReceiptsState copyWith({
    ReceiptBlocStatus? status,
    List<ReceiptEntity>? receipts,
    Failure? failure,
    bool? receiptCreated,
    bool clearFailure = false,
  }) {
    return ReceiptsState(
      status: status ?? this.status,
      receipts: receipts ?? this.receipts,
      failure: clearFailure ? null : (failure ?? this.failure),
      receiptCreated: receiptCreated ?? this.receiptCreated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          receipts == other.receipts &&
          failure == other.failure &&
          receiptCreated == other.receiptCreated;

  @override
  int get hashCode => Object.hash(status, receipts, failure, receiptCreated);

  @override
  String toString() =>
      'ReceiptsState(status: $status, receipts: ${receipts.length}, failure: $failure)';
}
