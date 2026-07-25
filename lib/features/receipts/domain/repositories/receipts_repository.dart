import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/receipt_entity.dart';

abstract class IReceiptsRepository {
  Future<Either<Failure, void>> save(ReceiptEntity receipt);
  Future<Either<Failure, List<ReceiptEntity>>> getAll();
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(String shiftId);
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(int year, int month);
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date);
  Future<Either<Failure, List<ReceiptEntity>>> getByStockNotUpdated();
}
