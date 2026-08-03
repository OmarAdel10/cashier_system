import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';

class FakeShiftsRepository implements IShiftsRepository {
  final _shifts = <String, ShiftEntity>{};
  ShiftEntity? _activeShift;

  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async =>
      Right(_activeShift);

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async =>
      Right(_shifts.values.toList());

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async {
    _shifts[shift.id] = shift;
    if (shift.endedAt == null) {
      _activeShift = shift;
    } else {
      _activeShift = null;
    }
    return const Right(null);
  }
}
