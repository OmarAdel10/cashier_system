import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';

class FakeShiftsRepository implements IShiftsRepository {
  final _shifts = <String, ShiftEntity>{};

  void addShift(ShiftEntity shift) => _shifts[shift.id] = shift;

  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async {
    final shift = _shifts.values.where((s) =>
        s.username == username && s.endedAt == null).firstOrNull;
    return Right(shift);
  }

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async {
    return Right(_shifts.values.where((s) =>
        s.startedAt.year == year && s.startedAt.month == month).toList());
  }

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async {
    _shifts[shift.id] = shift;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> closeOpenShifts(String username) async {
    for (final entry in _shifts.entries) {
      if (entry.value.username == username && entry.value.endedAt == null) {
        _shifts[entry.key] = entry.value.copyWith(endedAt: DateTime.now());
      }
    }
    return const Right(null);
  }
}

class FailingFakeShiftsRepository implements IShiftsRepository {
  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async {
    return Left(DatabaseFailure('Save failed'));
  }

  @override
  Future<Either<Failure, void>> closeOpenShifts(String username) async {
    return Left(DatabaseFailure('Close failed'));
  }
}
