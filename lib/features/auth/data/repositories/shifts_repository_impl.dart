import 'package:hive/hive.dart';

import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/shift_entity.dart';
import '../../domain/repositories/i_shifts_repository.dart';
import '../models/app_shift_model.dart';

class ShiftsRepositoryImpl implements IShiftsRepository {
  final Box<AppShiftModel> _box;
  final Box<String> _activeBox;

  ShiftsRepositoryImpl({required Box<AppShiftModel> box, required Box<String> activeBox})
      : _box = box,
        _activeBox = activeBox;

  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async {
    try {
      final shiftId = _activeBox.get(username);
      if (shiftId == null) return const Right(null);
      final model = _box.get(shiftId);
      if (model != null && model.endedAt == null) return Right(model.toEntity());
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get active shift: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async {
    try {
      final shifts = <ShiftEntity>[];
      for (final key in _box.keys) {
        final model = _box.get(key);
        if (model != null &&
            model.startedAt.year == year &&
            model.startedAt.month == month) {
          shifts.add(model.toEntity());
        }
      }
      return Right(shifts);
    } catch (e) {
      return Left(DatabaseFailure('Failed to get shifts by month: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async {
    try {
      final model = AppShiftModel(
        id: shift.id,
        username: shift.username,
        startedAt: shift.startedAt,
        endedAt: shift.endedAt,
        openingFloat: shift.openingFloat,
        orderCount: shift.orderCount,
      );
      await _box.put(shift.id, model);
      if (shift.endedAt == null) {
        await _activeBox.put(shift.username, shift.id);
      } else {
        await _activeBox.delete(shift.username);
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save shift: $e'));
    }
  }
}