import 'package:hive/hive.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/receipt_entity.dart';
import '../../domain/repositories/receipts_repository.dart';
import '../models/app_receipt_model.dart';

class ReceiptsRepositoryImpl implements IReceiptsRepository {
  final Box<AppReceiptModel> _box;
  ReceiptsRepositoryImpl({required Box<AppReceiptModel> box}) : _box = box;

  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async {
    try {
      final model = AppReceiptModel(
        id: receipt.id, shiftId: receipt.shiftId,
        orderNumber: receipt.orderNumber, items: receipt.items,
        subtotalPiastres: receipt.subtotalPiastres,
        discountPiastres: receipt.discountPiastres,
        taxPiastres: receipt.taxPiastres, totalPiastres: receipt.totalPiastres,
        createdAt: receipt.createdAt, username: receipt.username,
        stockUpdated: receipt.stockUpdated, status: receipt.status,
      );
      await _box.put(receipt.id, model);
      return const Right(null);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to save receipt'));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll() async {
    try {
      final list = _box.values.map((m) => m.toEntity()).toList();
      return Right(list);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load receipts'));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(String shiftId) async {
    try {
      final list = _box.values
          .where((m) => m.shiftId == shiftId)
          .map((m) => m.toEntity())
          .toList();
      return Right(list);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load receipts by shift'));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(int year, int month) async {
    try {
      final list = _box.values
          .where((m) {
            final d = m.createdAt;
            return d.year == year && d.month == month;
          })
          .map((m) => m.toEntity())
          .toList();
      return Right(list);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load receipts by month'));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async {
    try {
      final list = _box.values
          .where((m) {
            final d = m.createdAt;
            return d.year == date.year && d.month == date.month && d.day == date.day;
          })
          .map((m) => m.toEntity())
          .toList();
      return Right(list);
    } catch (e) {
      return Left(const DatabaseFailure('Failed to load receipts by date'));
    }
  }
}
