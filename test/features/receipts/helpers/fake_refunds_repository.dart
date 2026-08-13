import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/refunds_repository.dart';

class FakeRefundsRepository implements IRefundsRepository {
  final _refunds = <String, RefundEntity>{};
  List<RefundEntity> get savedRefunds => _refunds.values.toList();
  bool shouldFail = false;

  @override
  Future<Either<Failure, void>> save(RefundEntity refund) async {
    if (shouldFail) return Left(DatabaseFailure('Save failed'));
    _refunds[refund.id] = refund;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<RefundEntity>>> getByOriginalReceipt(
    String receiptId,
  ) async {
    return Right(
      _refunds.values.where((r) => r.originalReceiptId == receiptId).toList(),
    );
  }
}
