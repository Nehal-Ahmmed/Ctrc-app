import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

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
      return Right(user);
    } catch (e) {
      return Left(AuthFailure('Sign in failed: ${e.toString()}'));
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
      return Right(user);
    } catch (e) {
      return Left(AuthFailure('Sign up failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(AuthFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure('Sign out failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    try {
      await remoteDataSource.resetPassword(email);
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure('Password reset failed: ${e.toString()}'));
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
      return Right(user);
    } catch (e) {
      return Left(AuthFailure('Profile update failed: ${e.toString()}'));
    }
  }
}
