import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/refund_entity.dart';

abstract class IRefundsRepository {
  Future<Either<Failure, void>> save(RefundEntity refund);
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(
    String receiptId,
  );
}
