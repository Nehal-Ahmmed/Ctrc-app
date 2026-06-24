import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserModel>> signUp({
    required String email,
    required String password,
    required String name,
    String? address,    // Optional — null by default
    String? image_url,  // Optional — null by default
  });

  Future<Either<Failure, UserModel>> getCurrentUser();

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, void>> resetPassword(String email);

  Future<Either<Failure, UserModel>> updateProfile({
    String? name,
    String? address,
    String? image_url,
  });
}
