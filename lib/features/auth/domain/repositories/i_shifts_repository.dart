import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/shift_entity.dart';

abstract class IShiftsRepository {
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username);
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month);
  Future<Either<Failure, void>> save(ShiftEntity shift);
  Future<Either<Failure, void>> update(ShiftEntity shift);
}
