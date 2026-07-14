import '../../../../core/error/failure.dart';
import '../../domain/entities/receipt_entity.dart';

enum ReceiptBlocStatus { initial, loading, ready, error }

class ReceiptsState {
  final ReceiptBlocStatus status;
  final List<ReceiptEntity>? receipts;
  final Failure? failure;

  const ReceiptsState({this.status = ReceiptBlocStatus.initial, this.receipts, this.failure});

  ReceiptsState copyWith({
    ReceiptBlocStatus? status,
    List<ReceiptEntity>? receipts,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ReceiptsState(
      status: status ?? this.status,
      receipts: receipts ?? this.receipts,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          receipts == other.receipts &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, receipts, failure);

  @override
  String toString() => 'ReceiptsState(status: $status, receipts: ${receipts?.length}, failure: $failure)';
}
