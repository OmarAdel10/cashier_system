import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/refund_entity.dart';
import '../../domain/repositories/refunds_repository.dart';
import '../models/app_refund_model.dart';

class RefundsRepositoryImpl implements IRefundsRepository {
  final Box<AppRefundModel> _box;
  RefundsRepositoryImpl({required Box<AppRefundModel> box}) : _box = box;

  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async {
    try {
      final model = AppRefundModel(
        id: refund.id, originalReceiptId: refund.originalReceiptId,
        refundDate: refund.refundDate, amountRestored: refund.amountRestored,
        type: refund.type,
      );
      await _box.put(refund.id, model);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to save refund'));
    }
  }

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(String receiptId) async {
    try {
      final list = _box.values
          .where((m) => m.originalReceiptId == receiptId)
          .map((m) => m.toEntity())
          .toList();
      return Right(list);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load refunds'));
    }
  }
}
