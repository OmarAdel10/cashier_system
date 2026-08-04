import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';

class FakeShiftsRepository implements IShiftsRepository {
  final index = <String, String>{};
  final store = <String, ShiftEntity>{};

  bool getActiveShiftFails = false;
  bool saveFails = false;
  int failSaveOnCall = -1;
  int _saveCalls = 0;
  bool closeOpenShiftsFails = false;

  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async {
    if (getActiveShiftFails) return Left(DatabaseFailure('DB error'));
    final shiftId = index[username];
    if (shiftId != null) {
      final model = store[shiftId];
      if (model != null && model.endedAt == null) {
        if (model.username == username) return Right(model);
        index.remove(username);
        return const Right(null);
      }
      index.remove(username);
      return const Right(null);
    }
    for (final entry in store.entries) {
      if (entry.value.username == username && entry.value.endedAt == null) {
        index[username] = entry.key;
        return Right(entry.value);
      }
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async =>
      Right(store.values.toList());

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async {
    _saveCalls++;
    if (saveFails || (_saveCalls == failSaveOnCall)) {
      return Left(DatabaseFailure('DB error'));
    }
    store[shift.id] = shift;
    if (shift.endedAt == null) {
      index[shift.username] = shift.id;
    } else if (index[shift.username] == shift.id) {
      index.remove(shift.username);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> closeOpenShifts(String username) async {
    if (closeOpenShiftsFails) return Left(DatabaseFailure('DB error'));
    for (final entry in store.entries) {
      if (entry.value.username == username && entry.value.endedAt == null) {
        store[entry.key] = entry.value.copyWith(endedAt: DateTime.now());
      }
    }
    index.remove(username);
    return const Right(null);
  }
}
