import 'package:dio/dio.dart';
import '../../domain/models/user_model.dart';
import 'auth_local_datasource.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException([
    this.message = 'Your session has ended. Please sign in again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<bool> checkHealth();

  Future<UserModel> signIn({required String email, required String password});

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address, 
    String? image_url, 
  });

  Future<UserModel> getCurrentUser();

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  });

  Future<UserModel> uploadAvatar(String filePath);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  final AuthLocalDataSource localDataSource;

  AuthRemoteDataSourceImpl({
    Dio? dio,
    AuthLocalDataSource? localDataSource,
    String baseUrl =
        'https://ctrc-backend.onrender.com', 
  })  : localDataSource = localDataSource ?? AuthLocalDataSourceImpl(),
        dio =
           dio ??
           (Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 60),
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           )..interceptors.add(LogInterceptor(
               request: true,
               requestBody: true,
               responseBody: true,
               error: true,
             )));

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await dio.get('/api/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
        
        await localDataSource.saveToken(data['data']['token'] as String);

        return UserModel.fromJson(data['data']['user'] as Map<String, dynamic>);
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
    String? address, 
    String? image_url, 
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'confirmPassword': password, 
          
          if (address != null) 'address': address,
          if (image_url != null) 'imageUrl': image_url,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        
        await localDataSource.saveToken(data['data']['token'] as String);

        return UserModel.fromJson(data['data']['user'] as Map<String, dynamic>);
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
    final token = localDataSource.readToken();

    if (token == null) {
      throw const SessionExpiredException('You are not signed in.');
    }

    try {
      final response = await dio.get(
        '/api/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get current user');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        throw SessionExpiredException(
          _extractErrorMessage(e.response?.data) ??
              'Your session has ended. Please sign in again.',
        );
      }

      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Could not reach the server');
    }
  }

  @override
  Future<void> signOut() async {
    await localDataSource.clear();
  }

  @override
  Future<void> resetPassword(String email) async {
    
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = localDataSource.readToken();

    if (token == null) {
      throw const SessionExpiredException('You are not signed in.');
    }

    try {
      final response = await dio.put(
        '/api/users/me/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          _extractErrorMessage(response.data) ?? 'Failed to change password',
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Change password error');
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  }) async {
    final token = localDataSource.readToken();

    if (token == null) {
      throw const SessionExpiredException('You are not signed in.');
    }

    try {
      final response = await dio.put(
        '/api/users/me',
        data: {
          'name': name,
          'address': address,
          'imageUrl': image_url,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update profile');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Profile update error');
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }

  @override
  Future<UserModel> uploadAvatar(String filePath) async {
    final token = localDataSource.readToken();

    if (token == null) {
      throw const SessionExpiredException('You are not signed in.');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await dio.post(
        '/api/users/me/avatar',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to upload profile picture');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Upload profile picture error');
    }
  }
}
