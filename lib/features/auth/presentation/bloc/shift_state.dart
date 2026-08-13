import '../../../../core/error/failure.dart';
import '../../domain/entities/shift_entity.dart';

enum ShiftStatus { initial, loading, active, ended, error }

class ShiftState {
  final ShiftStatus status;
  final ShiftEntity? shift;
  final Failure? failure;
  final bool orphanRecovered;

  const ShiftState({
    this.status = ShiftStatus.initial,
    this.shift,
    this.failure,
    this.orphanRecovered = false,
  });

  ShiftState copyWith({
    ShiftStatus? status,
    ShiftEntity? shift,
    Failure? failure,
    bool? orphanRecovered,
    bool clearFailure = false,
    bool clearShift = false,
  }) {
    return ShiftState(
      status: status ?? this.status,
      shift: clearShift ? null : (shift ?? this.shift),
      failure: clearFailure ? null : (failure ?? this.failure),
      orphanRecovered: orphanRecovered ?? this.orphanRecovered,
    );
  }
}
