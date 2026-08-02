import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  /// The copy of the session that survives the app being closed.
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    AuthLocalDataSource? localDataSource,
  }) : localDataSource = localDataSource ?? AuthLocalDataSourceImpl();

  @override
  UserModel? cachedUser() => localDataSource.readSession()?.user;

  @override
  Future<Either<Failure, UserModel>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDataSource.signIn(
        email: email,
        password: password,
      );
      // From here the device can open as this person on its own.
      await localDataSource.saveUser(user);
      return Right(user);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, UserModel>> signUp({
    required String email,
    required String password,
    required String name,
    String? address,   // Optional — null by default
    String? image_url, // Optional — null by default
  }) async {
    try {
      final user = await remoteDataSource.signUp(
        email: email,
        password: password,
        name: name,
        address: address,
        image_url: image_url,
      );
      await localDataSource.saveUser(user);
      return Right(user);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      // Refreshes the stored profile, so a name or avatar changed on another
      // device is what the next cold start opens with.
      await localDataSource.saveUser(user);
      return Right(user);
    } on SessionExpiredException catch (e) {
      // The token is gone or was refused, so nothing kept beside it is usable.
      await localDataSource.clear();
      return Left(SessionExpiredFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    // Cleared first, and whatever the remote call does: a sign-out that leaves
    // the previous account's profile, feed or saved posts sitting on the device
    // is a worse outcome than one the server never hears about.
    await localDataSource.clear();

    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await remoteDataSource.resetPassword(email);
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, UserModel>> updateProfile({
    String? name,
    String? address,
    String? image_url,
  }) async {
    try {
      final user = await remoteDataSource.updateProfile(
        name: name,
        address: address,
        image_url: image_url,
      );
      await localDataSource.saveUser(user);
      return Right(user);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, UserModel>> uploadAvatar(String filePath) async {
    try {
      final user = await remoteDataSource.uploadAvatar(filePath);
      await localDataSource.saveUser(user);
      return Right(user);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(AppError.messageOf(e)));
    }
  }
}
