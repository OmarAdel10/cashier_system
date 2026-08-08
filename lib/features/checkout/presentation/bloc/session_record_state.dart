import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

enum SessionRecordBlocStatus { initial, loading, ready, error }

class SessionRecordState {
  final SessionRecordBlocStatus status;
  final List<SessionRecordEntity> records;
  final Failure? failure;

  const SessionRecordState({
    this.status = SessionRecordBlocStatus.initial,
    this.records = const [],
    this.failure,
  });

  SessionRecordState copyWith({
    SessionRecordBlocStatus? status,
    List<SessionRecordEntity>? records,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return SessionRecordState(
      status: status ?? this.status,
      records: records ?? this.records,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          records.length == other.records.length &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, records.length, failure);
}
