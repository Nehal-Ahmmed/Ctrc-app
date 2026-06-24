import 'package:dio/dio.dart';
import '../../domain/models/user_model.dart';

/// Abstract class for remote authentication data source
abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address, // Optional — null by default
    String? image_url, // Optional — null by default
  });

  Future<UserModel> getCurrentUser();

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({
    Dio? dio,
    String baseUrl =
        'http://192.168.3.105:8089', // Match server.port 8089 in backend application.properties
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 10),
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           );

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Backend returns AuthResponse: {token: ..., user: {...}}
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        throw Exception(
          _extractErrorMessage(response.data) ?? 'Failed to sign in',
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Sign in error');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address, // Optional — null by default
    String? image_url, // Optional — null by default
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'confirmPassword': password, // default confirmation match
          // Only include address & imageUrl if non-null; backend treats missing/null as NULL
          if (address != null) 'address': address,
          if (image_url != null) 'imageUrl': image_url,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        throw Exception(
          _extractErrorMessage(response.data) ?? 'Failed to sign up',
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Sign up error');
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    // In a full implementation, session/token management would fetch the current user details.
    throw UnimplementedError(
      'getCurrentUser session management not implemented',
    );
  }

  @override
  Future<void> signOut() async {
    // Local session clearing simulation
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> resetPassword(String email) async {
    // Reset password simulation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  }) async {
    // Profile update endpoint is not yet configured on the backend
    throw UnimplementedError(
      'updateProfile is not yet implemented on the backend endpoints',
    );
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }
}
