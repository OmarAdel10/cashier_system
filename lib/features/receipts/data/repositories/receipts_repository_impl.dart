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
        modificationCount: receipt.modificationCount,
      );
      await _box.put(receipt.id, model);
      return const Right(null);
    } catch (e) {
      return Left(ReceiptPersistenceFailure('Failed to save receipt', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll({int? limit}) async {
    try {
      final list = <ReceiptEntity>[];
      final count = _box.length;
      final max = limit ?? count;
      for (var i = count - 1; i >= 0 && list.length < max; i--) {
        list.add(_box.getAt(i)!.toEntity());
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load receipts', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(String shiftId) async {
    try {
      final list = <ReceiptEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = _box.getAt(i)!;
        if (m.shiftId == shiftId) list.add(m.toEntity());
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load receipts by shift', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(int year, int month) async {
    try {
      final list = <ReceiptEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = _box.getAt(i)!;
        final d = m.createdAt;
        if (d.year == year && d.month == month) list.add(m.toEntity());
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load receipts by month', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async {
    try {
      final list = <ReceiptEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = _box.getAt(i)!;
        final d = m.createdAt;
        if (d.year == date.year && d.month == date.month && d.day == date.day) {
          list.add(m.toEntity());
        }
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load receipts by date', cause: e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByStockNotUpdated() async {
    try {
      final list = <ReceiptEntity>[];
      for (var i = 0; i < _box.length; i++) {
        final m = _box.getAt(i)!;
        if (!m.stockUpdated) list.add(m.toEntity());
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure('Failed to read pending receipts', cause: e));
    }
  }
}
