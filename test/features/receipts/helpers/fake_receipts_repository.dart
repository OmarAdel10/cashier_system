import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/repositories/receipts_repository.dart';

class FakeReceiptsRepository implements IReceiptsRepository {
  final _receipts = <String, ReceiptEntity>{};

  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async {
    _receipts[receipt.id] = receipt;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll({int? limit}) async {
    var list = _receipts.values.toList();
    if (limit != null && limit < list.length) {
      list = list.sublist(list.length - limit);
    }
    return Right(list);
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(
    String shiftId,
  ) async {
    return Right(_receipts.values.where((r) => r.shiftId == shiftId).toList());
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(
    int year,
    int month,
  ) async {
    return Right(
      _receipts.values.where((r) {
        final d = r.createdAt;
        return d.year == year && d.month == month;
      }).toList(),
    );
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async {
    return Right(
      _receipts.values.where((r) {
        final d = r.createdAt;
        return d.year == date.year &&
            d.month == date.month &&
            d.day == date.day;
      }).toList(),
    );
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByYear(int year) async {
    return Right(
      _receipts.values.where((r) => r.createdAt.year == year).toList(),
    );
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByStockNotUpdated() async {
    final list = _receipts.values.where((r) => !r.stockUpdated).toList();
    return Right(list);
  }
}

class FailingFakeReceiptsRepository implements IReceiptsRepository {
  @override
  Future<Either<Failure, void>> save(ReceiptEntity receipt) async {
    return Left(DatabaseFailure('Save failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getAll({int? limit}) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByShift(
    String shiftId,
  ) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByMonth(
    int year,
    int month,
  ) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByDate(DateTime date) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByYear(int year) async {
    return Left(DatabaseFailure('Load failed'));
  }

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getByStockNotUpdated() async {
    return Left(DatabaseFailure('Load failed'));
  }
}
