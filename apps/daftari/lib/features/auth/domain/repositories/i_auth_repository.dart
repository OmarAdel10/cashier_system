import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../entities/user_entity.dart';

abstract class IAuthRepository {
  Future<Either<Failure, List<UserEntity>>> getAll();
  Future<Either<Failure, UserEntity?>> getByUsername(String username);
  Future<Either<Failure, void>> save(UserEntity user);
  Future<Either<Failure, void>> delete(String username);
  Future<Either<Failure, bool>> isSetupCompleted();
  Future<Either<Failure, void>> completeSetup(UserEntity admin);
  Future<Either<Failure, void>> retrySeeding();
}
