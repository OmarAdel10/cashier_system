import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/refund_entity.dart';
import '../../domain/repositories/refunds_repository.dart';
import '../models/app_refund_model.dart';

class RefundsRepositoryImpl implements IRefundsRepository {
  final LazyBox<AppRefundModel> _box;
  RefundsRepositoryImpl({required LazyBox<AppRefundModel> box}) : _box = box;

  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async {
    try {
      final model = AppRefundModel(
        id: refund.id,
        originalReceiptId: refund.originalReceiptId,
        refundDate: refund.refundDate,
        amountRestored: refund.amountRestored,
        type: refund.type,
      );
      await _box.put(refund.id, model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save refund', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(
    String receiptId,
  ) async {
    try {
      final list = <RefundEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = (await _box.getAt(i))!;
        if (m.originalReceiptId == receiptId) {
          list.add(m.toEntity());
        }
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load refunds', cause: e));
    }
  }
}
